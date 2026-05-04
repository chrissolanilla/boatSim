import { defineStore } from 'pinia'

import {
	calcDistance,
	calcFuelUsed,
	calcFuelWeight,
	calcPropShaftRPM,
	calcRecommendedFuel,
	calcSlipPercent,
	calcTheoreticalSpeed,
	calcTimeHours,
	buildRaceEstimateSnapshot,
	calculateWaveRoughness,
	calculateWindComponents,
	evaluateSpacerSetup,
	evaluateWindWaveSetup
} from '../utils/formulas'

function toNumber(v) {
	return typeof v === 'number' ? v : Number(v) || 0
}

function slipToTone(slip) {
	if (slip < 0) return 'bad'
	if (slip < 5) return 'warn'
	if (slip <= 20) return 'good'
	if (slip <= 25) return 'warn'
	return 'bad'
}

function slipToMessage(slip) {
	if (slip < 0) return 'negative slip usually means bad inputs or bad gps data'
	if (slip < 5) return 'very low slip, maybe too much drag or prop too deep'
	if (slip <= 20) return 'healthy slip range'
	if (slip <= 25) return 'slip is getting high, watch hookup'
	return 'too much slip, likely ventilation or poor bite'
}

function weatherToMessage(tempF, humidity) {
	if (tempF >= 90 && humidity >= 70) {
		return 'Hot and humid air. Expect weaker engine performance than a cool dry morning.'
	}
	if (tempF <= 70 && humidity <= 40) {
		return 'Cooler and drier air. Generally better for power.'
	}
	return 'Average air. Compare against baseline runs.'
}

function weatherToTone(tempF, humidity) {
	if (tempF >= 90 && humidity >= 70) return 'warn'
	if (tempF <= 70 && humidity <= 40) return 'good'
	return 'neutral'
}

function roughnessToMessage(roughness) {
	if (roughness >= 0.6) {
		return 'Short steep chop. Rough, constant hits, stability matters more than top speed.'
	}
	if (roughness >= 0.3) return 'Moderate chop. Watch trim and prop hookup.'
	return 'Water looks relatively manageable.'
}

function roughnessToTone(roughness) {
	if (roughness >= 0.6) return 'bad'
	if (roughness >= 0.3) return 'warn'
	return 'good'
}

function copyData(value) {
	return JSON.parse(JSON.stringify(value))
}

function sessionComparison(session) {
	const actualTime = toNumber(session.actualTimeSeconds)
	const estimatedTime = toNumber(session.estimatedTimeSeconds)
	const actualSpeed = toNumber(session.actualSpeedMph)
	const estimatedSpeed = toNumber(session.estimatedSpeedMph)
	const timeErrorSeconds = actualTime > 0 && estimatedTime > 0 ? actualTime - estimatedTime : null
	const speedErrorMph = actualSpeed > 0 && estimatedSpeed > 0 ? actualSpeed - estimatedSpeed : null
	const percentError = actualTime > 0 && estimatedTime > 0 ? (timeErrorSeconds / actualTime) * 100 : null

	return {
		timeErrorSeconds,
		speedErrorMph,
		percentError
	}
}

function csvValue(value) {
	const text = Array.isArray(value) ? value.join(' | ') : String(value ?? '')
	return `"${text.replace(/"/g, '""')}"`
}

export const useBoatSimStore = defineStore('boatSim', {
	state: () => ({
		propSlip: {
			pitch: 30,
			rpm: 6200,
			gearRatio: 1.29,
			gpsSpeed: 120
		},
		fuel: {
			laps: 5,
			lapMiles: 2,
			avgSpeed: 120,
			engines: 2,
			burnRate: 65
		},
		conditions: {
			tempF: 85,
			humidity: 65,
			windSpeed: 12,
			windDirection: 0,
			courseHeading: 0,
			waveHeight: 1.5,
			wavePeriod: 4,
			waveAngle: 0
		},
		spacer: {
			spacerSize: 1,
			waterCondition: 'flat',
			goal: 'top-speed',
			slipPercent: '',
			trim: 'neutral'
		},
		sessions: []
	}),
	getters: {
		propShaftRPM: (s) => calcPropShaftRPM(toNumber(s.propSlip.rpm), toNumber(s.propSlip.gearRatio)),
		theoreticalSpeed: (s) =>
			calcTheoreticalSpeed(
				toNumber(s.propSlip.pitch),
				toNumber(s.propSlip.rpm),
				toNumber(s.propSlip.gearRatio)
			),
		slip() {
			return calcSlipPercent(this.theoreticalSpeed, toNumber(this.propSlip.gpsSpeed))
		},
		slipTone() {
			return slipToTone(this.slip)
		},
		slipMessage() {
			return slipToMessage(this.slip)
		},

		distance: (s) => calcDistance(toNumber(s.fuel.laps), toNumber(s.fuel.lapMiles)),
		timeHours() {
			return calcTimeHours(this.distance, toNumber(this.fuel.avgSpeed))
		},
		fuelUsed() {
			return calcFuelUsed(toNumber(this.fuel.burnRate), toNumber(this.fuel.engines), this.timeHours)
		},
		fuelWeight() {
			return calcFuelWeight(this.fuelUsed)
		},
		recommendedFuel() {
			return calcRecommendedFuel(this.fuelUsed)
		},
		raceMinutes() {
			return this.timeHours * 60
		},

		roughness: (s) => {
			return calculateWaveRoughness({
				waveHeight: toNumber(s.conditions.waveHeight),
				wavePeriod: toNumber(s.conditions.wavePeriod)
			})
		},
		windComponents: (s) => calculateWindComponents({
			windSpeed: toNumber(s.conditions.windSpeed),
			windDirection: toNumber(s.conditions.windDirection),
			courseHeading: toNumber(s.conditions.courseHeading)
		}),
		windWaveEvaluation: (s) => evaluateWindWaveSetup({
			windSpeed: toNumber(s.conditions.windSpeed),
			windDirection: toNumber(s.conditions.windDirection),
			courseHeading: toNumber(s.conditions.courseHeading),
			waveHeight: toNumber(s.conditions.waveHeight),
			wavePeriod: toNumber(s.conditions.wavePeriod),
			waveAngle: toNumber(s.conditions.waveAngle)
		}),
		spacerEvaluation: (s) => evaluateSpacerSetup({
			spacerSize: toNumber(s.spacer.spacerSize),
			waterCondition: s.spacer.waterCondition,
			goal: s.spacer.goal,
			slipPercent: s.spacer.slipPercent,
			trim: s.spacer.trim
		}),
		weatherMessage: (s) => {
			const t = toNumber(s.conditions.tempF)
			const h = toNumber(s.conditions.humidity)
			return weatherToMessage(t, h)
		},
		waveMessage() {
			return roughnessToMessage(this.roughness)
		},
		weatherTone: (s) => {
			const t = toNumber(s.conditions.tempF)
			const h = toNumber(s.conditions.humidity)
			return weatherToTone(t, h)
		},
		waveTone() {
			return roughnessToTone(this.roughness)
		},
		roughnessTone() {
			return roughnessToTone(this.roughness)
		},
		raceEstimate() {
			return buildRaceEstimateSnapshot({
				propSlip: this.propSlip,
				fuel: this.fuel,
				conditions: this.conditions,
				spacer: this.spacer,
				theoreticalSpeed: this.theoreticalSpeed,
				slipPercent: this.slip,
				fuelWeight: this.fuelWeight,
				spacerEvaluation: this.spacerEvaluation,
				windWaveEvaluation: this.windWaveEvaluation
			})
		},
		sessionsWithComparisons: (s) => s.sessions.map((session) => ({
			...session,
			...sessionComparison(session)
		}))
	},
	actions: {
		createRaceEstimateSession() {
			const estimate = this.raceEstimate
			const id = `session-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
			const snapshot = {
				propSlip: copyData(this.propSlip),
				fuel: copyData(this.fuel),
				conditions: copyData(this.conditions),
				spacer: copyData(this.spacer),
				slipPercent: this.slip,
				theoreticalSpeed: this.theoreticalSpeed,
				fuelUsed: this.fuelUsed,
				fuelWeight: this.fuelWeight,
				recommendedFuel: this.recommendedFuel,
				windWaveEvaluation: copyData(this.windWaveEvaluation),
				spacerEvaluation: copyData(this.spacerEvaluation)
			}

			const session = {
				id,
				createdAt: new Date().toISOString(),
				estimatedSpeedMph: estimate.estimatedSpeedMph,
				theoreticalSpeedMph: estimate.theoreticalSpeedMph,
				netProgressSpeedMph: estimate.netProgressSpeedMph,
				estimatedTimeSeconds: estimate.estimatedTimeSeconds,
				distanceMiles: estimate.distanceMiles,
				isOutsideModelRange: estimate.isOutsideModelRange,
				modelRangeWarnings: copyData(estimate.modelRangeWarnings),
				confidenceLabel: estimate.confidenceLabel,
				confidenceTone: estimate.confidenceTone,
				breakdown: copyData(estimate.breakdown),
				warnings: copyData(estimate.warnings),
				notes: copyData(estimate.notes),
				snapshot,
				actualTimeSeconds: '',
				actualSpeedMph: '',
				actualNotes: '',
				completedAt: ''
			}

			this.sessions.unshift(session)
			return session
		},
		updateSessionActuals(sessionId, actuals) {
			const session = this.sessions.find((item) => item.id === sessionId)
			if (!session) return
			const actualTimeSeconds = actuals.actualTimeSeconds === '' ? '' : toNumber(actuals.actualTimeSeconds)
			let actualSpeedMph = actuals.actualSpeedMph === '' ? '' : toNumber(actuals.actualSpeedMph)

			if (!actualSpeedMph && actualTimeSeconds > 0 && session.distanceMiles > 0) {
				actualSpeedMph = session.distanceMiles / (actualTimeSeconds / 3600)
			}

			session.actualTimeSeconds = actualTimeSeconds
			session.actualSpeedMph = actualSpeedMph
			session.actualNotes = actuals.actualNotes ?? session.actualNotes
			session.completedAt = actualTimeSeconds || actualSpeedMph || session.actualNotes ? new Date().toISOString() : ''
		},
		deleteSession(sessionId) {
			this.sessions = this.sessions.filter((session) => session.id !== sessionId)
		},
		clearSessions() {
			this.sessions = []
		},
		exportSessionsCsv() {
			const headers = [
				'session id', 'created at', 'distance miles', 'estimated speed mph', 'net progress speed mph', 'theoretical speed mph', 'estimated time seconds',
				'actual speed mph', 'actual time seconds', 'time error seconds', 'speed error mph', 'percent error',
				'pitch', 'rpm', 'gear ratio', 'gps speed', 'slip percent', 'spacer size', 'water condition',
				'goal', 'trim', 'temp', 'humidity', 'wind speed', 'wind direction', 'course heading',
				'headwind component', 'crosswind component', 'wave height', 'wave period', 'wave angle',
				'wave roughness', 'fuel gallons estimated', 'fuel gallons recommended', 'confidence',
				'outside model range', 'model range warnings', 'warnings', 'notes', 'actual notes'
			]

			const rows = this.sessionsWithComparisons.map((session) => {
				const snapshot = session.snapshot || {}
				const propSlip = snapshot.propSlip || {}
				const fuel = snapshot.fuel || {}
				const conditions = snapshot.conditions || {}
				const spacer = snapshot.spacer || {}
				const wind = snapshot.windWaveEvaluation || {}
				return [
					session.id,
					session.createdAt,
					session.distanceMiles,
					session.estimatedSpeedMph,
					session.netProgressSpeedMph,
					session.theoreticalSpeedMph,
					session.estimatedTimeSeconds,
					session.actualSpeedMph,
					session.actualTimeSeconds,
					session.timeErrorSeconds,
					session.speedErrorMph,
					session.percentError,
					propSlip.pitch,
					propSlip.rpm,
					propSlip.gearRatio,
					propSlip.gpsSpeed,
					snapshot.slipPercent,
					spacer.spacerSize,
					spacer.waterCondition,
					spacer.goal,
					spacer.trim,
					conditions.tempF,
					conditions.humidity,
					conditions.windSpeed,
					conditions.windDirection,
					conditions.courseHeading,
					wind.headwindComponent,
					wind.crosswindComponent,
					conditions.waveHeight,
					conditions.wavePeriod,
					conditions.waveAngle,
					wind.roughness,
					snapshot.fuelUsed,
					snapshot.recommendedFuel,
					session.confidenceLabel,
					session.isOutsideModelRange,
					session.modelRangeWarnings,
					session.warnings,
					session.notes,
					session.actualNotes
				].map(csvValue).join(',')
			})

			return [headers.map(csvValue).join(','), ...rows].join('\n')
		}
	}
})

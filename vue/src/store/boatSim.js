import { defineStore } from 'pinia'

import {
	calcDistance,
	calcFuelUsed,
	calcFuelWeight,
	calcPropShaftRPM,
	calcRecommendedFuel,
	calcSlipPercent,
	calcTheoreticalSpeed,
	calcTimeHours
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
			waveHeight: 1.5,
			wavePeriod: 4
		}
	}),
	getters: {
		propShaftRPM: (s) => calcPropShaftRPM(toNumber(s.propSlip.rpm), toNumber(s.propSlip.gearRatio)),
		theoreticalSpeed: (s) =>
			calcTheoreticalSpeed(
				toNumber(s.propSlip.pitch),
				toNumber(s.propSlip.rpm),
				toNumber(s.propSlip.gearRatio)
			),
		slip: (s) => calcSlipPercent(s.theoreticalSpeed, toNumber(s.propSlip.gpsSpeed)),
		slipTone: (s) => slipToTone(s.slip),
		slipMessage: (s) => slipToMessage(s.slip),

		distance: (s) => calcDistance(toNumber(s.fuel.laps), toNumber(s.fuel.lapMiles)),
		timeHours: (s) => calcTimeHours(s.distance, toNumber(s.fuel.avgSpeed)),
		fuelUsed: (s) => calcFuelUsed(toNumber(s.fuel.burnRate), toNumber(s.fuel.engines), s.timeHours),
		fuelWeight: (s) => calcFuelWeight(s.fuelUsed),
		recommendedFuel: (s) => calcRecommendedFuel(s.fuelUsed),
		raceMinutes: (s) => s.timeHours * 60,

		roughness: (s) => {
			const wavePeriod = toNumber(s.conditions.wavePeriod)
			if (wavePeriod <= 0) return 0
			return toNumber(s.conditions.waveHeight) / wavePeriod
		},
		weatherMessage: (s) => {
			const t = toNumber(s.conditions.tempF)
			const h = toNumber(s.conditions.humidity)
			return weatherToMessage(t, h)
		},
		waveMessage: (s) => roughnessToMessage(s.roughness),
		weatherTone: (s) => {
			const t = toNumber(s.conditions.tempF)
			const h = toNumber(s.conditions.humidity)
			return weatherToTone(t, h)
		},
		waveTone: (s) => roughnessToTone(s.roughness),
		roughnessTone: (s) => roughnessToTone(s.roughness)
	}
})

export function calcTheoreticalSpeed(pitch, rpm, gearRatio) {
	if (!gearRatio) return 0
	return (pitch * rpm) / (gearRatio * 1056)
}

export function calcPropShaftRPM(engineRPM, gearRatio) {
	if (!gearRatio) return 0
	return engineRPM / gearRatio
}

export function calcSlipPercent(theoreticalSpeed, gpsSpeed) {
	if (!theoreticalSpeed) return 0
	return ((theoreticalSpeed - gpsSpeed) / theoreticalSpeed) * 100
}

export function calcDistance(laps, lapMiles) {
	return laps * lapMiles
}

export function calcTimeHours(distance, speed) {
	if (!speed) return 0
	return distance / speed
}

export function calcFuelUsed(burnRate, engines, timeHours) {
	return burnRate * engines * timeHours
}

export function calcFuelWeight(gallons) {
	return gallons * 6.1
}

export function calcRecommendedFuel(gallonsUsed) {
	return gallonsUsed * 1.33
}

function toFiniteNumber(value, fallback = 0) {
	const number = Number(value)
	return Number.isFinite(number) ? number : fallback
}

function normalizeDegrees(degrees) {
	return ((degrees % 360) + 360) % 360
}

function smallestAngle(degrees) {
	const normalized = normalizeDegrees(degrees)
	return normalized > 180 ? normalized - 360 : normalized
}

function spacerRiskTone(risk) {
	if (risk === 'high' || risk === 'very high') return 'bad'
	if (risk === 'moderate') return 'warn'
	return 'good'
}

export function evaluateSpacerSetup({
	spacerSize,
	waterCondition,
	goal,
	slipPercent = null,
	trim = 'neutral'
}) {
	const size = toFiniteNumber(spacerSize, 1)
	const slip = slipPercent === '' || slipPercent === null ? null : toFiniteNumber(slipPercent, null)

	let propPosition = 'moderate depth / baseline setback'
	let dragEstimateLabel = 'baseline drag estimate'
	let ventilationRisk = 'moderate'
	let recommendation = 'Use this as a baseline and confirm with GPS speed, RPM, and prop slip.'

	if (size <= 0.5) {
		propPosition = 'deeper prop / more bite'
		dragEstimateLabel = 'more drag, more hookup'
		ventilationRisk = 'low'
		recommendation = 'Good direction for rougher water, acceleration, or when the prop is losing bite. It may give up some top speed from extra drag.'
	} else if (size <= 1) {
		propPosition = 'balanced depth / normal bite'
		dragEstimateLabel = 'baseline to mild drag reduction'
		ventilationRisk = 'low to moderate'
		recommendation = 'Good starting range for mixed conditions. Make one change at a time and compare slip against GPS speed.'
	} else if (size <= 1.75) {
		propPosition = 'raised prop / less gearcase drag'
		dragEstimateLabel = 'may reduce drag in clean water'
		ventilationRisk = 'moderate'
		recommendation = 'May help top-end testing in flatter water, but confirm the gain with RPM, GPS speed, and prop slip instead of trusting the estimate.'
	} else if (size <= 2.5) {
		propPosition = 'high prop / aggressive setback'
		dragEstimateLabel = 'larger rule-of-thumb drag reduction'
		ventilationRisk = 'high'
		recommendation = 'Treat this as a careful test setup, not a default. Watch for RPM climbing faster than GPS speed, which points toward ventilation.'
	} else {
		propPosition = 'maximum setback / very high prop attitude'
		dragEstimateLabel = 'maximum rough estimate, least margin'
		ventilationRisk = 'very high'
		recommendation = 'Use only as a cautious test idea in very clean water. Confirm clearance, handling, RPM, GPS speed, and slip before drawing conclusions.'
	}

	const warnings = []
	const notes = []

	if (waterCondition === 'rough' && size > 1) {
		warnings.push('Rough water with a larger spacer may increase ventilation and handling risk. Test carefully and consider stepping down if bite is inconsistent.')
	} else if (waterCondition === 'chop' && size > 1.75) {
		warnings.push('Chop with an aggressive spacer may make bite inconsistent. Watch RPM and GPS speed together.')
	}

	if (goal === 'corner' && size > 1.5) {
		notes.push('For corner/acceleration work, a smaller spacer may give steadier bite than chasing less drag.')
	}

	if (goal === 'rough' && size > 1) {
		notes.push('For rough-water stability, prioritize repeatable hookup over a top-speed spacer estimate.')
	}

	if (trim === 'high' && size >= 2) {
		warnings.push('High trim with a large spacer reduces margin. Treat this as a caution and verify attitude on the water.')
	}

	if (slip !== null) {
		if (slip < 5) {
			notes.push('Current slip is very low. The prop may be loaded hard or running deep; compare against RPM before increasing spacer.')
		} else if (slip <= 20) {
			notes.push('Current slip is in a useful rule-of-thumb range. Change spacer in small steps and log the result.')
		} else if (slip <= 25) {
			warnings.push('Current slip is getting high. More spacer may increase ventilation unless GPS speed improves with RPM.')
		} else {
			warnings.push('Current slip is very high. Confirm inputs and look for ventilation, prop damage, or poor bite before increasing spacer.')
		}
	}

	return {
		propPosition,
		dragEstimateLabel,
		ventilationRisk,
		tone: spacerRiskTone(ventilationRisk),
		recommendation,
		notes,
		warnings
	}
}

export function calculateWindComponents({ windSpeed, windDirection, courseHeading }) {
	const speed = Math.max(toFiniteNumber(windSpeed), 0)
	const relativeAngle = smallestAngle(toFiniteNumber(windDirection) - toFiniteNumber(courseHeading))
	const radians = relativeAngle * Math.PI / 180

	return {
		relativeAngle,
		headwindComponent: speed * Math.cos(radians),
		crosswindComponent: speed * Math.sin(radians)
	}
}

export function calculateWaveRoughness({ waveHeight, wavePeriod }) {
	const period = toFiniteNumber(wavePeriod)
	if (period <= 0) return 0
	return Math.max(toFiniteNumber(waveHeight), 0) / period
}

export function evaluateWindWaveSetup({
	windSpeed,
	windDirection,
	courseHeading,
	waveHeight,
	wavePeriod,
	waveAngle
}) {
	const wind = calculateWindComponents({ windSpeed, windDirection, courseHeading })
	const roughness = calculateWaveRoughness({ waveHeight, wavePeriod })
	const angle = Math.abs(toFiniteNumber(waveAngle))
	const notes = []

	let conditionLabel = 'manageable conditions'
	let tone = 'good'

	if (roughness >= 0.6) {
		conditionLabel = 'short, steep chop'
		tone = 'bad'
		notes.push('Wave height compared with period suggests steep chop. Setup should favor control and repeatable bite over top speed.')
	} else if (roughness >= 0.3) {
		conditionLabel = 'moderate chop'
		tone = 'warn'
		notes.push('Water is not flat. Log spacer, trim, RPM, GPS speed, and slip before calling a setup faster.')
	} else {
		notes.push('Wave roughness is low by this simple height/period rule-of-thumb.')
	}

	if (wind.headwindComponent > 12) {
		notes.push('Strong headwind component may increase aero load and drag. Avoid treating speed loss as only a prop issue.')
	} else if (wind.headwindComponent < -12) {
		notes.push('Strong tailwind component may change tunnel feel and reduce the margin for aggressive trim. Test carefully.')
	}

	if (Math.abs(wind.crosswindComponent) > 10) {
		notes.push('Crosswind component is meaningful. Watch tracking, turn entry, and whether one sponson feels loaded.')
	}

	if (angle >= 60) {
		notes.push('Beam or quartering waves can make corner behavior less predictable than the roughness number alone suggests.')
	} else if (angle <= 20 && roughness >= 0.3) {
		notes.push('Mostly head-on waves with chop can pound the sponsons. Throttle and trim notes matter here.')
	}

	return {
		...wind,
		roughness,
		conditionLabel,
		tone,
		notes
	}
}

function clamp(value, min, max) {
	return Math.min(Math.max(value, min), max)
}

function round(value, places = 1) {
	const scale = 10 ** places
	return Math.round(value * scale) / scale
}

function weatherModifier(tempF, humidity) {
	const temp = toFiniteNumber(tempF, 77)
	const humid = toFiniteNumber(humidity, 50)
	const heatPenalty = temp > 80 ? -((temp - 80) * 0.035) : 0
	const humidityPenalty = humid > 60 ? -((humid - 60) * 0.015) : 0
	const coolHelp = temp < 70 && humid < 55 ? 0.5 : 0
	return clamp(heatPenalty + humidityPenalty + coolHelp, -2.5, 0.8)
}

function slipModifier(slipPercent) {
	const slip = toFiniteNumber(slipPercent)
	if (slip < 0) return -4
	if (slip < 5) return -1.2
	if (slip <= 20) return 0
	if (slip <= 25) return -1.8
	return -4
}

function spacerModifier({ spacer, spacerEvaluation, slipPercent }) {
	const size = toFiniteNumber(spacer?.spacerSize, 1)
	const water = spacer?.waterCondition
	const goal = spacer?.goal
	const risk = spacerEvaluation?.ventilationRisk || 'moderate'
	const slip = toFiniteNumber(slipPercent)
	let modifier = 0

	if (size >= 1.25 && size <= 1.75 && water === 'flat' && goal === 'top-speed') modifier += 0.8
	if (size <= 0.5 && goal === 'top-speed') modifier -= 1.1
	if (size > 1.75 && water === 'chop') modifier -= 1.4
	if (size > 1 && water === 'rough') modifier -= 2.5
	if (risk === 'high') modifier -= 1
	if (risk === 'very high') modifier -= 2
	if (slip > 22 && size > 1.25) modifier -= 1.5

	return clamp(modifier, -4, 1)
}

function windModifier(windWaveEvaluation, baseSpeed) {
	const headwind = toFiniteNumber(windWaveEvaluation?.headwindComponent)
	const crosswind = Math.abs(toFiniteNumber(windWaveEvaluation?.crosswindComponent))
	const windSpeed = Math.hypot(headwind, crosswind)
	const outsideRange = windSpeed > 80 || Math.abs(headwind) > 60 || crosswind > 40
	const headwindPenalty = headwind > 0 ? -(0.045 * headwind + 0.002 * headwind ** 2) : 0
	const tailwindHelp = headwind < 0 ? Math.min(Math.abs(headwind) * 0.035, 2.5) : 0
	const crossPenalty = crosswind > 8 ? -(0.015 * (crosswind - 8) ** 1.35) : 0
	const value = headwindPenalty + tailwindHelp + crossPenalty

	return {
		value,
		note: outsideRange
			? `${round(windSpeed, 0)} mph wind input is outside the calculator range. Modifier is extrapolated, not validated.`
			: `wind ${round(windSpeed, 0)} mph, head/tail ${round(headwind, 1)} mph, cross ${round(crosswind, 1)} mph; nonlinear rule-of-thumb modifier`
	}
}

function waveModifier(roughness) {
	return clamp(-(toFiniteNumber(roughness) * 6), -5, 0)
}

function fuelModifier(fuelWeight) {
	return clamp(-(toFiniteNumber(fuelWeight) / 400), -2, 0)
}

export function estimateRaceSpeed(input) {
	const propSlip = input.propSlip || {}
	const fuel = input.fuel || {}
	const conditions = input.conditions || {}
	const spacer = input.spacer || {}
	const theoreticalSpeed = toFiniteNumber(input.theoreticalSpeed)
	const slipPercent = toFiniteNumber(input.slipPercent)
	const gpsSpeed = toFiniteNumber(propSlip.gpsSpeed)
	const baseSpeed = gpsSpeed > 0 ? gpsSpeed : theoreticalSpeed * (1 - clamp(slipPercent, 0, 60) / 100)
	const spacerEvaluation = input.spacerEvaluation || evaluateSpacerSetup({ ...spacer, slipPercent })
	const windWaveEvaluation = input.windWaveEvaluation || evaluateWindWaveSetup(conditions)
	const fuelWeight = toFiniteNumber(input.fuelWeight, calcFuelWeight(toFiniteNumber(fuel.burnRate) * toFiniteNumber(fuel.engines)))
	const wind = windModifier(windWaveEvaluation, baseSpeed)

	const modifiers = [
		{
			label: 'Slip quality',
			value: slipModifier(slipPercent),
			unit: 'mph',
			note: slipPercent >= 5 && slipPercent <= 20 ? 'healthy rule-of-thumb slip range' : 'slip is outside the preferred range'
		},
		{
			label: 'Outdrive spacer',
			value: spacerModifier({ spacer, spacerEvaluation, slipPercent }),
			unit: 'mph',
			note: 'small rule-of-thumb spacer adjustment, not a guaranteed speed change'
		},
		{
			label: 'Weather',
			value: weatherModifier(conditions.tempF, conditions.humidity),
			unit: 'mph',
			note: 'hot/humid air is treated as a small power penalty'
		},
		{
			label: 'Wind',
			value: wind.value,
			unit: 'mph',
			note: wind.note
		},
		{
			label: 'Waves',
			value: waveModifier(windWaveEvaluation.roughness),
			unit: 'mph',
			note: 'wave roughness uses height / period as a simple chop estimate'
		},
		{
			label: 'Fuel weight',
			value: fuelModifier(fuelWeight),
			unit: 'mph',
			note: 'conservative penalty from estimated fuel weight'
		}
	]

	const totalModifier = modifiers.reduce((sum, item) => sum + item.value, 0)
	const rawEstimatedSpeed = baseSpeed + totalModifier
	// Practical speed is for time math; net progress preserves extrapolated results for silly inputs.
	const practicalSpeed = Math.max(rawEstimatedSpeed, 0)

	return {
		estimatedSpeedMph: round(practicalSpeed, 1),
		theoreticalSpeedMph: round(theoreticalSpeed, 1),
		netProgressSpeedMph: round(rawEstimatedSpeed, 1),
		baseSpeed: round(baseSpeed, 1),
		breakdown: [
			{
				label: 'Base speed',
				value: round(baseSpeed, 1),
				unit: 'mph',
				note: gpsSpeed > 0 ? 'from current GPS speed input' : 'from theoretical speed adjusted by slip'
			},
			...modifiers.map((item) => ({ ...item, value: round(item.value, 1) })),
			{
				label: 'Total modifier',
				value: round(totalModifier, 1),
				unit: 'mph',
				note: 'raw modifier total; practical speed is clamped at zero only for time math'
			}
		]
	}
}

export function estimateRaceTime({ distanceMiles, estimatedSpeedMph }) {
	const distance = toFiniteNumber(distanceMiles)
	const speed = toFiniteNumber(estimatedSpeedMph)
	if (distance <= 0 || speed <= 0) return null
	return (distance / speed) * 3600
}

function modelRangeWarnings(input, speedEstimate) {
	const conditions = input.conditions || {}
	const wind = input.windWaveEvaluation || {}
	const warnings = []
	const windSpeed = toFiniteNumber(conditions.windSpeed)
	const waveHeight = toFiniteNumber(conditions.waveHeight)
	const roughness = toFiniteNumber(wind.roughness)
	const headwind = Math.abs(toFiniteNumber(wind.headwindComponent))
	const crosswind = Math.abs(toFiniteNumber(wind.crosswindComponent))

	if (windSpeed > 80) warnings.push('Wind speed is above 80 mph, outside the normal calculator range.')
	if (headwind > 60) warnings.push('Head/tail wind component is above 60 mph, outside the normal calculator range.')
	if (crosswind > 40) warnings.push('Crosswind component is above 40 mph, outside the normal calculator range.')
	if (waveHeight > 10) warnings.push('Wave height is above 10 ft, outside the normal calculator range.')
	if (roughness > 2.5) warnings.push('Wave roughness is above 2.5, outside the normal calculator range.')
	if (speedEstimate.netProgressSpeedMph <= 0) {
		warnings.push('The extrapolated model predicts no forward progress for this course direction. This is a silly/outside-range scenario, not a validated physical prediction.')
	}

	return warnings
}

export function buildRaceEstimateSnapshot(input) {
	const speedEstimate = estimateRaceSpeed(input)
	const distanceMiles = calcDistance(toFiniteNumber(input.fuel?.laps), toFiniteNumber(input.fuel?.lapMiles))
	const estimatedTimeSeconds = estimateRaceTime({ distanceMiles, estimatedSpeedMph: speedEstimate.estimatedSpeedMph })
	const modelWarnings = modelRangeWarnings(input, speedEstimate)
	const warnings = []
	const notes = [
		'Rough estimate based on current calculator inputs, not a full race-engineering simulation.',
		'Compare against actual run data before trusting setup direction.'
	]
	const slip = toFiniteNumber(input.slipPercent)
	const roughness = toFiniteNumber(input.windWaveEvaluation?.roughness)
	const crosswind = Math.abs(toFiniteNumber(input.windWaveEvaluation?.crosswindComponent))

	if (slip < 0 || slip > 25) warnings.push('Large uncertainty because prop slip is abnormal or inputs may be wrong.')
	if (roughness >= 0.6) warnings.push('Large uncertainty because wave roughness is high.')
	if (crosswind > 12) warnings.push('Crosswind is meaningful; handling may matter more than the speed estimate.')
	if (input.spacerEvaluation?.tone === 'bad') warnings.push('Spacer setup has high ventilation risk in the current rule-of-thumb evaluation.')
	if (modelWarnings.length) {
		warnings.push('Outside calculator range. The app is still showing extrapolated math, but this should not be treated as a real race prediction.')
		warnings.push(...modelWarnings)
	}

	const confidencePenalty = warnings.length + (roughness >= 0.3 ? 1 : 0) + (Math.abs(toFiniteNumber(input.windWaveEvaluation?.headwindComponent)) > 15 ? 1 : 0)
	const isOutsideModelRange = modelWarnings.length > 0
	const confidenceLabel = isOutsideModelRange ? 'outside model range' : confidencePenalty >= 3 ? 'low confidence' : confidencePenalty >= 1 ? 'medium confidence' : 'reasonable confidence'
	const confidenceTone = isOutsideModelRange ? 'bad' : confidencePenalty >= 3 ? 'bad' : confidencePenalty >= 1 ? 'warn' : 'good'

	return {
		estimatedSpeedMph: speedEstimate.estimatedSpeedMph,
		theoreticalSpeedMph: speedEstimate.theoreticalSpeedMph,
		netProgressSpeedMph: speedEstimate.netProgressSpeedMph,
		estimatedTimeSeconds: estimatedTimeSeconds === null ? null : round(estimatedTimeSeconds, 1),
		distanceMiles: round(distanceMiles, 2),
		isOutsideModelRange,
		modelRangeWarnings: modelWarnings,
		confidenceLabel,
		confidenceTone,
		breakdown: speedEstimate.breakdown,
		warnings,
		notes
	}
}

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

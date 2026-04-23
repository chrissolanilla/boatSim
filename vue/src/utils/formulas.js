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

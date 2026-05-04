<script setup>
import { RouterLink } from 'vue-router'
import { useBoatSimStore } from '../store/boatSim'

import SectionCard from '../components/SectionCard.vue'
import MetricCard from '../components/MetricCard.vue'

const store = useBoatSimStore()

const propShaftRpmHelp = 'prop shaft RPM = engine RPM / gear ratio.'
const theoreticalSpeedHelp =
	"Theoretical speed ignores slip. Formula (mph): (pitch(in) * engine RPM) / (gear ratio * 1056).\n\n1056 converts inches/min to mph."
const slipHelp =
	"Slip % = ((theoretical - GPS) / theoretical) * 100.\n\nRule-of-thumb bands: 5-20% is often a healthy range, 20-25% is getting high, >25% usually means poor bite/ventilation. Negative slip usually means bad inputs or GPS."

const distanceHelp = 'Distance = laps * lap miles.'
const raceTimeHelp = 'Race time (minutes) = (distance / avg speed) * 60.'
const fuelUsedHelp = 'Fuel used (gal) = burn rate (GPH) * engines * time (hours).'
const fuelWeightHelp = 'Fuel weight uses ~6.1 lb/gal as a rough gasoline density.'
const recommendedFuelHelp =
	'Recommended fuel = fuel used * 1.33. This is a common 1/3 safety buffer rule of thumb for contingencies; tune it to your risk tolerance and conditions.'

const roughnessHelp =
	'Heuristic: roughness = wave height (ft) / wave period (sec). Higher values mean steeper, shorter-period chop.\n\nRule of thumb bands here: <0.30 manageable, 0.30-0.60 moderate, >=0.60 steep/rough.'
const spacerHelp =
	'Rule-of-thumb spacer guidance. Confirm with GPS speed, RPM, and prop slip before trusting a setup change.'
const windHelp =
	'Wind and wave guidance uses course-relative components and a simple wave height / period roughness score.'
const raceEstimateHelp =
	'Rough estimate based on current calculator inputs. It is not a full race-engineering simulation.'

function formatTime(seconds) {
	if (seconds === null || seconds === undefined) return 'no valid finish estimate'
	const total = Math.max(Number(seconds) || 0, 0)
	const minutes = Math.floor(total / 60)
	const remainder = Math.round(total % 60)
	return `${minutes}m ${String(remainder).padStart(2, '0')}s`
}
</script>

<template>
	<h1 class="page-title">Boat Sim Dashboard</h1>
	<p class="page-subtitle">Overall readout. Use the edit links to change inputs, then calculate a race estimate.</p>

	<div class="page-stack">

		<SectionCard title="Prop Slip" subtitle="Inputs and live calculated slip.">
			<div class="metric-stack">
				<MetricCard
					label="Prop shaft RPM"
					:value="store.propShaftRPM.toFixed(0)"
					:help="propShaftRpmHelp"
				/>
				<MetricCard
					label="Theoretical speed"
					:value="`${store.theoreticalSpeed.toFixed(1)} mph`"
					:help="theoreticalSpeedHelp"
				/>
				<MetricCard
					label="Slip"
					:value="`${store.slip.toFixed(1)}%`"
					:tone="store.slipTone"
					:help="slipHelp"
				/>
			</div>
			<div class="status" :class="store.slipTone">{{ store.slipMessage }}</div>
			<div class="button-row actions">
				<RouterLink class="button-link" to="/calculator/prop-slip">Edit prop slip</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Fuel" subtitle="Race planning numbers.">
			<div class="metric-stack narrow">
				<MetricCard label="Distance" :value="`${store.distance.toFixed(1)} mi`" :help="distanceHelp" />
				<MetricCard label="Race time" :value="`${store.raceMinutes.toFixed(1)} min`" :help="raceTimeHelp" />
				<MetricCard label="Fuel used" :value="`${store.fuelUsed.toFixed(1)} gal`" :help="fuelUsedHelp" />
				<MetricCard label="Fuel weight" :value="`${store.fuelWeight.toFixed(0)} lbs`" :help="fuelWeightHelp" />
				<MetricCard
					label="Recommended fuel"
					:value="`${store.recommendedFuel.toFixed(1)} gal`"
					tone="warn"
					:help="recommendedFuelHelp"
				/>
			</div>
			<div class="button-row actions">
				<RouterLink class="button-link" to="/calculator/fuel">Edit fuel</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Conditions" subtitle="Guidance only, not exact physics.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Roughness"
					:value="store.roughness.toFixed(2)"
					:tone="store.roughnessTone"
					:help="roughnessHelp"
				/>
			</div>
			<div class="note" :class="store.weatherTone">{{ store.weatherMessage }}</div>
			<div class="note" :class="store.waveTone">{{ store.waveMessage }}</div>
			<div class="button-row actions">
				<RouterLink class="button-link" to="/calculator/conditions">Edit conditions</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Outdrive Spacer" subtitle="M8 spacer guidance without fake precision.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Spacer"
					:value="`${Number(store.spacer.spacerSize).toFixed(2)} in`"
					:help="spacerHelp"
				/>
				<MetricCard
					label="Ventilation risk"
					:value="store.spacerEvaluation.ventilationRisk"
					:tone="store.spacerEvaluation.tone"
					:help="spacerHelp"
				/>
			</div>
			<div class="note" :class="store.spacerEvaluation.tone">
				{{ store.spacerEvaluation.recommendation }}
			</div>
			<div class="button-row actions">
				<RouterLink class="button-link" to="/calculator/outdrive-spacer">Edit spacer</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Wind & Compass" subtitle="Course-relative wind and wave readout.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Head/tail"
					:value="`${store.windWaveEvaluation.headwindComponent.toFixed(1)} mph`"
					:help="windHelp"
				/>
				<MetricCard
					label="Crosswind"
					:value="`${store.windWaveEvaluation.crosswindComponent.toFixed(1)} mph`"
					:help="windHelp"
				/>
				<MetricCard
					label="Water label"
					:value="store.windWaveEvaluation.conditionLabel"
					:tone="store.windWaveEvaluation.tone"
					:help="windHelp"
				/>
			</div>
			<div class="button-row actions">
				<RouterLink class="button-link" to="/calculator/wind">Edit wind</RouterLink>
			</div>
		</SectionCard>

	</div>

	<div>

		<SectionCard style="background: #2f2133;" title="Race Estimate" subtitle="Rough estimate based on the current calculator inputs.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Estimated speed"
					:value="`${store.raceEstimate.estimatedSpeedMph.toFixed(1)} mph`"
					:help="raceEstimateHelp"
				/>
				<MetricCard
					label="Estimated time"
					:value="formatTime(store.raceEstimate.estimatedTimeSeconds)"
					:help="raceEstimateHelp"
				/>
				<MetricCard
					v-if="store.raceEstimate.isOutsideModelRange"
					label="Net extrapolated speed"
					:value="`${store.raceEstimate.netProgressSpeedMph.toFixed(1)} mph`"
					tone="bad"
					:help="raceEstimateHelp"
				/>
				<MetricCard
					label="Distance"
					:value="`${store.raceEstimate.distanceMiles.toFixed(2)} mi`"
					:help="distanceHelp"
				/>
				<MetricCard
					label="Confidence"
					:value="store.raceEstimate.confidenceLabel"
					:tone="store.raceEstimate.confidenceTone"
					:help="raceEstimateHelp"
				/>
			</div>

			<div v-if="store.raceEstimate.isOutsideModelRange" class="note bad outside-range">
				<strong>Outside calculator range.</strong>
				<p>The app is still showing the extrapolated math, but this should not be treated as a real race prediction.</p>
				<p v-for="warning in store.raceEstimate.modelRangeWarnings" :key="warning">{{ warning }}</p>
			</div>

			<div class="breakdown">
				<div v-for="item in store.raceEstimate.breakdown" :key="item.label" class="breakdown-row">
					<span>{{ item.label }}</span>
					<strong>{{ item.value > 0 && item.label !== 'Base speed' ? '+' : '' }}{{ item.value }} {{ item.unit }}</strong>
					<small>{{ item.note }}</small>
				</div>
			</div>

			<div v-if="store.raceEstimate.warnings.length" class="note bad">
				<p v-for="warning in store.raceEstimate.warnings" :key="warning">{{ warning }}</p>
			</div>
			<div class="note neutral">
				<p v-for="note in store.raceEstimate.notes" :key="note">{{ note }}</p>
			</div>

			<div class="button-row actions">
				<button class="button" type="button" @click="store.createRaceEstimateSession()">
					Log this estimate
				</button>
				<RouterLink class="button-link" to="/sessions">View sessions</RouterLink>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.status {
	margin-top: 1rem;
	padding: 1rem;
	border-radius: 16px;
	line-height: 1.5;
	border: 1px solid rgba(255, 255, 255, 0.08);
	background: rgba(255, 255, 255, 0.04);
}

.status.good {
	border-color: rgba(63, 211, 140, 0.4);
}

.status.warn {
	border-color: rgba(255, 177, 74, 0.42);
}

.status.bad {
	border-color: rgba(255, 110, 122, 0.42);
}

.note {
	padding: 0.9rem 1rem;
	border-radius: 14px;
	background: rgba(255, 255, 255, 0.04);
	border: 1px solid rgba(255, 255, 255, 0.07);
	margin-bottom: 0.75rem;
	line-height: 1.5;
	color: var(--muted-text);
}

.note.good {
	border-color: rgba(63, 211, 140, 0.35);
}

.note.warn {
	border-color: rgba(255, 177, 74, 0.35);
}

.note.bad {
	border-color: rgba(255, 110, 122, 0.35);
}

.actions {
	margin-top: 0.25rem;
}

.breakdown {
	display: flex;
	flex-direction: column;
	gap: 0.55rem;
	margin: 1rem 0;
}

.breakdown-row {
	display: flex;
	align-items: baseline;
	gap: 0.65rem;
	flex-wrap: wrap;
	padding: 0.7rem 0.8rem;
	border-radius: 14px;
	background: rgba(255, 255, 255, 0.035);
	border: 1px solid rgba(255, 255, 255, 0.06);
}

.breakdown-row span {
	font-weight: 700;
}

.breakdown-row strong {
	margin-left: auto;
}

.breakdown-row small {
	flex: 1 1 100%;
	color: var(--muted-text);
	line-height: 1.35;
}

.note p {
	margin: 0;
}

.outside-range strong {
	color: rgba(255, 255, 255, 0.92);
}
</style>

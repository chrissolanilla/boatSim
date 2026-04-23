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
</script>

<template>
	<h1 class="page-title">Boat Sim Dashboard</h1>
	<p class="page-subtitle">Overall readout. Use the edit links to change inputs.</p>

	<div class="grid grid-2">
		<SectionCard title="Prop Slip" subtitle="Inputs and live calculated slip.">
			<div class="grid grid-3">
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
			<div class="actions">
				<RouterLink class="action" to="/calculator/prop-slip">Edit prop slip</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Fuel" subtitle="Race planning numbers.">
			<div class="grid grid-2">
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
			<div class="actions">
				<RouterLink class="action" to="/calculator/fuel">Edit fuel</RouterLink>
			</div>
		</SectionCard>

		<SectionCard title="Conditions" subtitle="Guidance only, not exact physics.">
			<div class="grid grid-2">
				<MetricCard
					label="Roughness"
					:value="store.roughness.toFixed(2)"
					:tone="store.roughnessTone"
					:help="roughnessHelp"
				/>
			</div>
			<div class="note" :class="store.weatherTone">{{ store.weatherMessage }}</div>
			<div class="note" :class="store.waveTone">{{ store.waveMessage }}</div>
			<div class="actions">
				<RouterLink class="action" to="/calculator/conditions">Edit conditions</RouterLink>
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

.action {
	display: inline-block;
	padding: 0.55rem 0.8rem;
	border-radius: 14px;
	border: 1px solid rgba(255, 255, 255, 0.1);
	background: rgba(0, 0, 0, 0.18);
	text-decoration: none;
}

.action:hover {
	border-color: rgba(47, 193, 232, 0.42);
}
</style>

<script setup>
import { useBoatSimStore } from '../../store/boatSim'

import SectionCard from '../../components/SectionCard.vue'
import MetricCard from '../../components/MetricCard.vue'
import NumberInput from '../../components/NumberInput.vue'

const store = useBoatSimStore()

const propShaftRpmHelp = 'prop shaft RPM = engine RPM / gear ratio.'

const theoreticalSpeedHelp =
	"Theoretical speed ignores slip. Formula (mph): (pitch(in) * engine RPM) / (gear ratio * 1056).\n\n1056 converts inches/min to mph."

const slipHelp =
	"Slip % = ((theoretical - GPS) / theoretical) * 100.\n\nRule-of-thumb bands: 5-20% is often a healthy range, 20-25% is getting high, >25% usually means poor bite/ventilation. Negative slip usually means bad inputs or GPS." 
</script>

<template>
	<h1 class="page-title">Prop Slip</h1>
	<p class="page-subtitle">
		One of the best pages in the whole tool because the math is actually defendable.
	</p>

	<div class="page-stack">
		<SectionCard title="Inputs" subtitle="Enter your setup numbers.">
			<NumberInput v-model="store.propSlip.pitch" label="Pitch (inches)" step="0.5" />
			<NumberInput v-model="store.propSlip.rpm" label="Engine RPM" step="50" />
			<NumberInput v-model="store.propSlip.gearRatio" label="Gear ratio" step="0.01" />
			<NumberInput v-model="store.propSlip.gpsSpeed" label="GPS speed (mph)" step="0.1" />
		</SectionCard>

		<SectionCard title="Results" subtitle="Live calculated values.">
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
</style>

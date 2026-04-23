<script setup>
import { useBoatSimStore } from '../../store/boatSim'

import SectionCard from '../../components/SectionCard.vue'
import MetricCard from '../../components/MetricCard.vue'
import NumberInput from '../../components/NumberInput.vue'

const store = useBoatSimStore()

const distanceHelp = 'Distance = laps * lap miles.'

const raceTimeHelp = 'Race time (minutes) = (distance / avg speed) * 60.'

const fuelUsedHelp = 'Fuel used (gal) = burn rate (GPH) * engines * time (hours).'

const fuelWeightHelp = 'Fuel weight uses ~6.1 lb/gal as a rough gasoline density.'

const recommendedFuelHelp =
	'Recommended fuel = fuel used * 1.33. This is a common 1/3 safety buffer rule of thumb for contingencies; tune it to your risk tolerance and conditions.'
</script>

<template>
	<h1 class="page-title">Fuel</h1>
	<p class="page-subtitle">Simple race planning numbers. good for owner / throttleman / crew.</p>

	<div class="grid grid-2">
		<SectionCard title="Inputs" subtitle="Race length and burn assumptions.">
			<NumberInput v-model="store.fuel.laps" label="Laps" step="1" />
			<NumberInput v-model="store.fuel.lapMiles" label="Lap miles" step="0.1" />
			<NumberInput v-model="store.fuel.avgSpeed" label="Average speed (mph)" step="1" />
			<NumberInput v-model="store.fuel.engines" label="Engines" step="1" />
			<NumberInput v-model="store.fuel.burnRate" label="Burn rate per engine (GPH)" step="1" />
		</SectionCard>

		<SectionCard title="Results" subtitle="Fuel load and race time.">
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
		</SectionCard>
	</div>
</template>

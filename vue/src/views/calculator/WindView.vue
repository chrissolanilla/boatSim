<script setup>
import { computed } from 'vue'
import { useBoatSimStore } from '../../store/boatSim'

import SectionCard from '../../components/SectionCard.vue'
import MetricCard from '../../components/MetricCard.vue'
import NumberInput from '../../components/NumberInput.vue'

const store = useBoatSimStore()

const evaluation = computed(() => store.windWaveEvaluation)
// const arrowRotation = computed(() => `${evaluation.value.relativeAngle}deg`)
const arrowRotation = computed(() => `${evaluation.value.relativeAngle + 180}deg`)

const headwindLabel = computed(() => {
	const value = evaluation.value.headwindComponent
	if (Math.abs(value) < 0.5) return 'near neutral'
	return value > 0 ? `${value.toFixed(1)} mph headwind` : `${Math.abs(value).toFixed(1)} mph tailwind`
})

const crosswindLabel = computed(() => {
	const value = evaluation.value.crosswindComponent
	if (Math.abs(value) < 0.5) return 'near neutral'
	return value > 0 ? `${value.toFixed(1)} mph from right` : `${Math.abs(value).toFixed(1)} mph from left`
})

const windHelp =
	'Wind direction is absolute compass direction the wind is coming from. Course heading is the direction the boat is traveling. Components are relative to the course.'

const waveHelp =
	'Roughness = wave height (ft) / wave period (sec). This is a simple steepness rule-of-thumb, not a full sea-state model.'
</script>

<template>
	<h1 class="page-title">Wind & Compass</h1>
	<p class="page-subtitle">
		Course-relative wind and wave guidance. Useful for notes, not a full race-engineering simulation.
	</p>

	<div class="page-stack">
		<SectionCard title="Inputs" subtitle="Use compass degrees. Wind direction means where the wind comes from.">
			<NumberInput v-model="store.conditions.windSpeed" label="Wind speed (mph)" :min="0" :max="80" step="1" />
			<NumberInput v-model="store.conditions.windDirection" label="Wind direction from (degrees)" :min="0" :max="359" step="1" />
			<NumberInput v-model="store.conditions.courseHeading" label="Course heading (degrees)" :min="0" :max="359" step="1" />
			<NumberInput v-model="store.conditions.waveHeight" label="Wave height (ft)" :min="0" :max="10" step="0.1" />
			<NumberInput v-model="store.conditions.wavePeriod" label="Wave period (sec)" :min="0" :max="30" step="0.1" />
			<NumberInput v-model="store.conditions.waveAngle" label="Wave angle to course (degrees)" :min="0" :max="90" step="1" />
		</SectionCard>

		<!-- <SectionCard title="Compass" subtitle="Arrow shows wind direction relative to the course heading."> -->
		<SectionCard title="Compass" subtitle="Arrow shows airflow direction across the boat. Wind direction itself means where the wind comes from.">
			<div class="compass-wrap">
				<div class="compass" aria-hidden="true">
					<span class="mark north">Bow</span>
					<span class="mark south">Stern</span>
					<span class="mark west">L</span>
					<span class="mark east">R</span>
					<div class="course-line" />
					<div class="wind-arrow" :style="{ transform: `translate(-50%, -50%) rotate(${arrowRotation})` }" />
				</div>

				<div class="compass-copy">
					<strong>{{ Math.round(evaluation.relativeAngle) }}° relative wind</strong>
					<p>0° means wind from ahead of the boat. 180° means wind from behind.</p>
				</div>
			</div>

			<div class="metric-stack narrow">
				<MetricCard label="Head/tail component" :value="headwindLabel" :help="windHelp" />
				<MetricCard label="Crosswind component" :value="crosswindLabel" :help="windHelp" />
				<MetricCard
					label="Wave roughness"
					:value="evaluation.roughness.toFixed(2)"
					:tone="evaluation.tone"
					:help="waveHelp"
				/>
			</div>
		</SectionCard>

		<SectionCard title="Readout" subtitle="Plain-English guidance from rough estimates.">
			<div class="note" :class="evaluation.tone">
				<strong>{{ evaluation.conditionLabel }}</strong>
				<p v-for="note in evaluation.notes" :key="note">{{ note }}</p>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.compass-wrap {
	display: flex;
	align-items: center;
	gap: 1rem;
	margin-bottom: 1rem;
	flex-wrap: wrap;
}

.compass {
	position: relative;
	width: 170px;
	height: 170px;
	flex: 0 0 auto;
	border-radius: 999px;
	border: 1px solid rgba(255, 255, 255, 0.18);
	background:
		radial-gradient(circle, rgba(47, 193, 232, 0.14) 0 42%, transparent 43%),
		linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.02));
}

.course-line {
	position: absolute;
	left: 50%;
	top: 14px;
	bottom: 14px;
	width: 2px;
	transform: translateX(-50%);
	background: rgba(255, 255, 255, 0.18);
}

.wind-arrow {
	position: absolute;
	left: 50%;
	top: 50%;
	width: 4px;
	height: 68px;
	transform-origin: 50% 50%;
	background: var(--primary-color);
	border-radius: 999px;
}

.wind-arrow::before {
	content: '';
	position: absolute;
	left: 50%;
	top: -7px;
	width: 15px;
	height: 15px;
	transform: translateX(-50%) rotate(45deg);
	border-left: 4px solid var(--primary-color);
	border-top: 4px solid var(--primary-color);
}

.mark {
	position: absolute;
	font-size: 0.75rem;
	font-weight: 800;
	color: rgba(255, 255, 255, 0.78);
}

.north {
	top: 0.5rem;
	left: 50%;
	transform: translateX(-50%);
}

.south {
	bottom: 0.5rem;
	left: 50%;
	transform: translateX(-50%);
}

.west {
	left: 0.65rem;
	top: 50%;
	transform: translateY(-50%);
}

.east {
	right: 0.65rem;
	top: 50%;
	transform: translateY(-50%);
}

.compass-copy {
	min-width: 0;
	max-width: 360px;
	color: var(--muted-text);
	line-height: 1.45;
}

.compass-copy strong {
	display: block;
	margin-bottom: 0.35rem;
	color: rgba(255, 255, 255, 0.9);
}

.compass-copy p,
.note p {
	margin: 0;
}

.note {
	display: flex;
	flex-direction: column;
	gap: 0.5rem;
	padding: 1rem;
	border-radius: 14px;
	border: 1px solid rgba(255, 255, 255, 0.08);
	background: rgba(255, 255, 255, 0.04);
	color: var(--muted-text);
	line-height: 1.5;
}

.note strong {
	color: rgba(255, 255, 255, 0.9);
}

.note.good {
	border-color: rgba(63, 211, 140, 0.35);
}

.note.warn {
	border-color: rgba(255, 177, 74, 0.35);
}

.note.bad {
	border-color: rgba(255, 110, 122, 0.42);
}

@media (max-width: 520px) {
	.compass-wrap {
		justify-content: center;
		text-align: center;
	}
}
</style>

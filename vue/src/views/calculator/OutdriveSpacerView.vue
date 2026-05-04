<script setup>
import { computed } from 'vue'
import { useBoatSimStore } from '../../store/boatSim'

import SectionCard from '../../components/SectionCard.vue'
import MetricCard from '../../components/MetricCard.vue'
import NumberInput from '../../components/NumberInput.vue'

const store = useBoatSimStore()

const spacerEvaluation = computed(() => store.spacerEvaluation)

const spacerHelp =
	'Spacer advice here is a rule-of-thumb estimate. Use GPS speed, RPM, and prop slip logs before calling a spacer change better.'

const riskHelp =
	'Ventilation risk is estimated from spacer size, water condition, trim, and optional current slip. It is not a full race-engineering simulation.'

const slipHelp =
	'Optional. If you have a current prop slip number from the Prop Slip page, enter it here so spacer advice can react to actual hookup.'
</script>

<template>
	<h1 class="page-title">Outdrive Spacer</h1>
	<p class="page-subtitle">
		M8 spacer setup notes for GC Racing. Rule-of-thumb only; confirm changes with GPS speed, RPM, and prop slip.
	</p>

	<div class="page-stack">
		<SectionCard title="Inputs" subtitle="Change one thing at a time and log the result.">
			<label class="field">
				<span>Spacer size: {{ Number(store.spacer.spacerSize).toFixed(2) }}&quot;</span>
				<input
					v-model.number="store.spacer.spacerSize"
					type="range"
					min="0.25"
					max="3"
					step="0.25"
				/>
			</label>

			<label class="field">
				<span>Water condition</span>
				<select v-model="store.spacer.waterCondition">
					<option value="flat">Flat / clean water</option>
					<option value="chop">Light to moderate chop</option>
					<option value="rough">Rough water</option>
				</select>
			</label>

			<label class="field">
				<span>Goal</span>
				<select v-model="store.spacer.goal">
					<option value="top-speed">Top speed testing</option>
					<option value="corner">Corner / acceleration</option>
					<option value="rough">Rough-water stability</option>
				</select>
			</label>

			<NumberInput
				v-model="store.spacer.slipPercent"
				label="Current slip percent (optional)"
				:min="-20"
				:max="60"
				step="0.1"
			/>
			<p class="hint">{{ slipHelp }}</p>

			<label class="field">
				<span>Trim setting</span>
				<select v-model="store.spacer.trim">
					<option value="down">Tucked / down</option>
					<option value="neutral">Neutral</option>
					<option value="high">High / aired out</option>
				</select>
			</label>
		</SectionCard>

		<SectionCard title="Readout" subtitle="Cautious setup guidance, not guaranteed speed.">
			<div class="metric-stack narrow">
				<MetricCard
					label="Prop position"
					:value="spacerEvaluation.propPosition"
					:help="spacerHelp"
				/>
				<MetricCard
					label="Drag estimate"
					:value="spacerEvaluation.dragEstimateLabel"
					:help="spacerHelp"
				/>
				<MetricCard
					label="Ventilation risk"
					:value="spacerEvaluation.ventilationRisk"
					:tone="spacerEvaluation.tone"
					:help="riskHelp"
				/>
			</div>

			<div class="note" :class="spacerEvaluation.tone">
				<strong>Recommendation</strong>
				<p>{{ spacerEvaluation.recommendation }}</p>
			</div>

			<div v-if="spacerEvaluation.notes.length" class="note neutral">
				<strong>Setup notes</strong>
				<p v-for="note in spacerEvaluation.notes" :key="note">{{ note }}</p>
			</div>

			<div v-if="spacerEvaluation.warnings.length" class="note bad">
				<strong>Cautions</strong>
				<p v-for="warning in spacerEvaluation.warnings" :key="warning">{{ warning }}</p>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.field {
	display: flex;
	flex-direction: column;
	gap: 0.45rem;
	margin-bottom: 0.95rem;
	color: var(--muted-text);
}

input[type='range'] {
	width: 100%;
	accent-color: var(--primary-color);
}

select {
	width: 100%;
	min-height: 44px;
	padding: 0.8rem 0.9rem;
	border-radius: 14px;
	border: 1px solid rgba(255, 255, 255, 0.1);
	background: rgba(0, 0, 0, 0.18);
	color: white;
}

.hint {
	margin: -0.45rem 0 0.95rem;
	color: var(--muted-text);
	font-size: 0.88rem;
	line-height: 1.45;
}

.note {
	display: flex;
	flex-direction: column;
	gap: 0.45rem;
	padding: 0.9rem 1rem;
	border-radius: 14px;
	background: rgba(255, 255, 255, 0.04);
	border: 1px solid rgba(255, 255, 255, 0.08);
	margin-top: 0.8rem;
	line-height: 1.5;
	color: var(--muted-text);
}

.note strong {
	color: rgba(255, 255, 255, 0.86);
}

.note p {
	margin: 0;
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
</style>

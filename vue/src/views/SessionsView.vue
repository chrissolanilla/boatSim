<script setup>
import { useBoatSimStore } from '../store/boatSim'
import SectionCard from '../components/SectionCard.vue'
import MetricCard from '../components/MetricCard.vue'

const store = useBoatSimStore()

function formatTime(seconds) {
	if (seconds === null || seconds === undefined) return 'no valid finish estimate'
	const total = Math.max(Number(seconds) || 0, 0)
	const minutes = Math.floor(total / 60)
	const remainder = Math.round(total % 60)
	return `${minutes}m ${String(remainder).padStart(2, '0')}s`
}

function formatDate(value) {
	return new Date(value).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })
}

function actualMinutes(session) {
	return Math.floor((Number(session.actualTimeSeconds) || 0) / 60)
}

function actualSeconds(session) {
	return Math.round((Number(session.actualTimeSeconds) || 0) % 60)
}

function updateActualTime(session, minutes, seconds) {
	const totalSeconds = (Number(minutes) || 0) * 60 + (Number(seconds) || 0)
	store.updateSessionActuals(session.id, {
		actualTimeSeconds: totalSeconds || '',
		actualSpeedMph: session.actualSpeedMph,
		actualNotes: session.actualNotes
	})
}

function updateActualSpeed(session, value) {
	store.updateSessionActuals(session.id, {
		actualTimeSeconds: session.actualTimeSeconds,
		actualSpeedMph: value,
		actualNotes: session.actualNotes
	})
}

function updateActualNotes(session, value) {
	store.updateSessionActuals(session.id, {
		actualTimeSeconds: session.actualTimeSeconds,
		actualSpeedMph: session.actualSpeedMph,
		actualNotes: value
	})
}

function downloadCsv() {
	const csv = store.exportSessionsCsv()
	const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
	const url = URL.createObjectURL(blob)
	const link = document.createElement('a')
	link.href = url
	link.download = `boatSim_sessions_${new Date().toISOString().slice(0, 10)}.csv`
	link.click()
	URL.revokeObjectURL(url)
}
</script>

<template>
	<h1 class="page-title">Sessions</h1>
	<p class="page-subtitle">
		Logged race estimates and actual results. Sessions are only created when you click “Log this estimate” on Home.
	</p>

	<div class="button-row session-actions">
		<button class="button" type="button" :disabled="!store.sessions.length" @click="downloadCsv">
			Export CSV
		</button>
		<button class="button danger" type="button" :disabled="!store.sessions.length" @click="store.clearSessions()">
			Clear sessions
		</button>
	</div>

	<div v-if="!store.sessions.length" class="page-stack">
		<SectionCard title="Session log" subtitle="No estimates logged yet.">
			<div class="empty-state">
				<p>Create an estimate from the Home page when the current calculator inputs represent a setup you want to track.</p>
			</div>
		</SectionCard>
	</div>

	<div v-else class="session-list">
		<SectionCard
			v-for="session in store.sessionsWithComparisons"
			:key="session.id"
			:title="`Estimate from ${formatDate(session.createdAt)}`"
			:subtitle="`Confidence: ${session.confidenceLabel}`"
		>
			<div class="metric-stack narrow">
				<MetricCard label="Estimated speed" :value="`${Number(session.estimatedSpeedMph).toFixed(1)} mph`" />
				<MetricCard
					v-if="session.isOutsideModelRange"
					label="Net extrapolated speed"
					:value="`${Number(session.netProgressSpeedMph).toFixed(1)} mph`"
					tone="bad"
				/>
				<MetricCard label="Estimated time" :value="formatTime(session.estimatedTimeSeconds)" />
				<MetricCard label="Distance" :value="`${Number(session.distanceMiles).toFixed(2)} mi`" />
				<MetricCard label="Confidence" :value="session.confidenceLabel" :tone="session.confidenceTone" />
			</div>

			<div class="setup-line">
				<span>Pitch {{ session.snapshot.propSlip.pitch }}&quot;</span>
				<span>{{ session.snapshot.propSlip.rpm }} RPM</span>
				<span>{{ session.snapshot.propSlip.gearRatio }} gear</span>
				<span>{{ Number(session.snapshot.spacer.spacerSize).toFixed(2) }}&quot; spacer</span>
				<span>{{ session.snapshot.conditions.windSpeed }} mph wind</span>
				<span>{{ session.snapshot.conditions.waveHeight }} ft / {{ session.snapshot.conditions.wavePeriod }} sec waves</span>
				<span>{{ Number(session.snapshot.recommendedFuel).toFixed(1) }} gal fuel rec.</span>
			</div>

			<details class="details">
				<summary>Estimate breakdown</summary>
				<div class="breakdown">
					<div v-for="item in session.breakdown" :key="item.label" class="breakdown-row">
						<span>{{ item.label }}</span>
						<strong>{{ item.value > 0 && item.label !== 'Base speed' ? '+' : '' }}{{ item.value }} {{ item.unit }}</strong>
						<small>{{ item.note }}</small>
					</div>
				</div>
			</details>

			<div v-if="session.warnings.length" class="note bad">
				<p v-for="warning in session.warnings" :key="warning">{{ warning }}</p>
			</div>

			<details class="details actuals" open>
				<summary>Actual results</summary>
				<div class="actual-form">
					<label>
						<span>Actual minutes</span>
						<input
							type="number"
							min="0"
							step="1"
							:value="actualMinutes(session)"
							@input="updateActualTime(session, $event.target.value, actualSeconds(session))"
						/>
					</label>
					<label>
						<span>Actual seconds</span>
						<input
							type="number"
							min="0"
							max="59"
							step="1"
							:value="actualSeconds(session)"
							@input="updateActualTime(session, actualMinutes(session), $event.target.value)"
						/>
					</label>
					<label>
						<span>Actual avg speed (optional)</span>
						<input
							type="number"
							min="0"
							step="0.1"
							:value="session.actualSpeedMph"
							@input="updateActualSpeed(session, $event.target.value)"
						/>
					</label>
					<label class="wide">
						<span>Actual notes</span>
						<textarea
							rows="3"
							:value="session.actualNotes"
							placeholder="Race notes, handling, setup feel, GPS/RPM observations..."
							@input="updateActualNotes(session, $event.target.value)"
						/>
					</label>
				</div>

				<div v-if="session.actualTimeSeconds || session.actualSpeedMph" class="metric-stack narrow comparison">
					<MetricCard label="Actual time" :value="formatTime(session.actualTimeSeconds)" />
					<MetricCard label="Time error" :value="`${Number(session.timeErrorSeconds || 0).toFixed(1)} sec`" />
					<MetricCard label="Actual speed" :value="`${Number(session.actualSpeedMph || 0).toFixed(1)} mph`" />
					<MetricCard label="Speed error" :value="`${Number(session.speedErrorMph || 0).toFixed(1)} mph`" />
					<MetricCard label="Percent error" :value="`${Number(session.percentError || 0).toFixed(1)}%`" />
				</div>
			</details>

			<div class="button-row">
				<button class="button danger" type="button" @click="store.deleteSession(session.id)">
					Delete session
				</button>
			</div>
		</SectionCard>
	</div>
</template>

<style scoped>
.session-actions {
	margin-bottom: 1rem;
}

.session-list {
	display: flex;
	flex-direction: column;
	gap: 1rem;
}

.empty-state,
.note {
	display: flex;
	flex-direction: column;
	gap: 0.65rem;
	padding: 1rem;
	border-radius: 16px;
	background: rgba(255, 255, 255, 0.03);
	color: var(--muted-text);
	line-height: 1.5;
}

.empty-state {
	border: 1px dashed rgba(255, 255, 255, 0.18);
}

.note.bad {
	border: 1px solid rgba(255, 110, 122, 0.42);
}

.setup-line {
	display: flex;
	flex-wrap: wrap;
	gap: 0.5rem;
	margin: 1rem 0;
}

.setup-line span {
	padding: 0.45rem 0.65rem;
	border-radius: 999px;
	background: rgba(255, 255, 255, 0.05);
	color: var(--muted-text);
	font-size: 0.9rem;
}

.details {
	margin: 1rem 0;
}

summary {
	cursor: pointer;
	font-weight: 800;
	min-height: 44px;
	display: flex;
	align-items: center;
}

.breakdown {
	display: flex;
	flex-direction: column;
	gap: 0.55rem;
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

.breakdown-row strong {
	margin-left: auto;
}

.breakdown-row small {
	flex: 1 1 100%;
	color: var(--muted-text);
	line-height: 1.35;
}

.actual-form {
	display: flex;
	flex-wrap: wrap;
	gap: 0.9rem;
}

label {
	display: flex;
	flex: 1 1 180px;
	min-width: 0;
	flex-direction: column;
	gap: 0.45rem;
	color: var(--muted-text);
}

label.wide {
	flex-basis: 100%;
}

input,
textarea {
	width: 100%;
	min-height: 44px;
	padding: 0.8rem 0.9rem;
	border-radius: 14px;
	border: 1px solid rgba(255, 255, 255, 0.1);
	background: rgba(0, 0, 0, 0.18);
	color: white;
}

textarea {
	resize: vertical;
}

.comparison {
	margin-top: 1rem;
}

.danger {
	border-color: rgba(255, 110, 122, 0.35);
}

button:disabled {
	opacity: 0.45;
	cursor: not-allowed;
}

p {
	margin: 0;
}
</style>

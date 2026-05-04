import { createRouter, createWebHistory } from 'vue-router'

import HomeView from '../views/HomeView.vue'
import PropSlipView from '../views/calculator/PropSlipView.vue'
import FuelView from '../views/calculator/FuelView.vue'
import ConditionsView from '../views/calculator/ConditionsView.vue'
import OutdriveSpacerView from '../views/calculator/OutdriveSpacerView.vue'
import WindView from '../views/calculator/WindView.vue'
import SessionsView from '../views/SessionsView.vue'

const routes = [
	{ path: '/', name: 'home', component: HomeView },
	{ path: '/calculator/prop-slip', name: 'prop-slip', component: PropSlipView },
	{ path: '/calculator/fuel', name: 'fuel', component: FuelView },
	{ path: '/calculator/conditions', name: 'conditions', component: ConditionsView },
	{ path: '/calculator/outdrive-spacer', name: 'outdrive-spacer', component: OutdriveSpacerView },
	{ path: '/calculator/wind', name: 'wind', component: WindView },
	{ path: '/sessions', name: 'sessions', component: SessionsView }
]

const router = createRouter({
	history: createWebHistory(import.meta.env.BASE_URL),
	routes
})

export default router

import { createRouter, createWebHistory } from 'vue-router'

import HomeView from '../views/HomeView.vue'
import PropSlipView from '../views/calculator/PropSlipView.vue'
import FuelView from '../views/calculator/FuelView.vue'
import ConditionsView from '../views/calculator/ConditionsView.vue'
import SessionsView from '../views/SessionsView.vue'

const router = createRouter({
	history: createWebHistory(),
	routes: [
		{ path: '/', name: 'home', component: HomeView },
		{ path: '/calculator/prop-slip', name: 'prop-slip', component: PropSlipView },
		{ path: '/calculator/fuel', name: 'fuel', component: FuelView },
		{ path: '/calculator/conditions', name: 'conditions', component: ConditionsView },
		{ path: '/sessions', name: 'sessions', component: SessionsView }
	]
})

export default router

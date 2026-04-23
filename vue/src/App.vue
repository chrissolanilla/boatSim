<template>
  <Navbar />
  <div class="app-shell">
    <div class="page-wrap">
      <RouterView />
    </div>
  </div>
  <Footer />
</template>

<script setup>
import { RouterView } from 'vue-router'
import Navbar from './components/Navbar.vue'
import Footer from './components/Footer.vue'
</script>

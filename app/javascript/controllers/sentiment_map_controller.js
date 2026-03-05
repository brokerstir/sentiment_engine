import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { points: Array }

  initialize() {
    console.log("1. Stimulus: Controller Initialized")
  }

  connect() {
    console.log("2. Stimulus: Controller Connected to:", this.element)
    console.log("3. Data Points:", this.pointsValue)

    const ctx = this.element.getContext('2d')
    if (!ctx) {
      console.error("4. Error: Canvas context not found")
      return
    }

    new Chart(ctx, {
      type: 'scatter',
      data: { datasets: this.pointsValue },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: { min: -1, max: 1, title: { display: true, text: 'Sentiment' } },
          y: { min: 0, max: 1, title: { display: true, text: 'Intensity' } }
        }
      }
    })
  }
}
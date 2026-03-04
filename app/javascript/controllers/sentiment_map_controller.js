import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

console.log("!!! SCRIPT LOADED: sentiment_map_controller.js is executing !!!")

export default class extends Controller {
  static values = { points: Array }

  connect() {
    console.log("!!! STIMULUS CONNECTED: Element is:", this.element)
    console.log("!!! DATA POINTS RECEIVED:", this.pointsValue)

    const ctx = this.element.getContext('2d')
    if (!ctx) {
      console.error("!!! ERROR: Could not get 2D context from canvas !!!")
      return
    }

    new Chart(ctx, {
      type: 'scatter',
      data: { datasets: this.pointsValue },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: { min: -1, max: 1, title: { display: true, text: 'Score' } },
          y: { min: 0, max: 1, title: { display: true, text: 'Intensity' } }
        }
      }
    })
  }
}

    export function renderDashboardCharts (lLabels, lData, dLabels, dData, dColors) {
        if (typeof Chart === 'undefined') {
            let script = document.createElement('script');
            script.src = 'js/chart.umd.js';
            script.onload = () => initCharts(lLabels, lData, dLabels, dData, dColors);
            document.head.appendChild(script);
        } else {
            initCharts(lLabels, lData, dLabels, dData, dColors);
        }

        function initCharts(labels1, data1, labels2, data2, colors2) {
            let ctxLine = document.getElementById('dashboardLineChart');
            if (ctxLine) {
                let existingLine = Chart.getChart(ctxLine);
                if (existingLine) existingLine.destroy();
                new Chart(ctxLine, {
                    type: 'line',
                    data: { labels: labels1, datasets: [{ label: 'Doanh thu (đ)', data: data1, borderColor: '#398675', backgroundColor: 'rgba(57, 134, 117, 0.10)', borderWidth: 3, fill: true, tension: 0.4 }] },
                    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true }, x: { grid: { display: false } } } }
                });
            }

            let ctxDonut = document.getElementById('dashboardDonutChart');
            if (ctxDonut) {
                let existingDonut = Chart.getChart(ctxDonut);
                if (existingDonut) existingDonut.destroy();
                new Chart(ctxDonut, {
                    type: 'doughnut',
                    data: { labels: labels2, datasets: [{ data: data2, backgroundColor: colors2, borderWidth: 0 }] },
                    options: { responsive: true, maintainAspectRatio: false, cutout: '75%', plugins: { legend: { display: false } } }
                });
            }
        }
    }

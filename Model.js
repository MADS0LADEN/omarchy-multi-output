function emptyStatus() {
  return {
    ok: false,
    enabled: false,
    sink: "omarchy_multi_output",
    slaves: [],
    previousDefault: "",
    available: []
  }
}

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (!text) return emptyStatus()
  try {
    var parsed = JSON.parse(text)
  } catch (e) {
    return emptyStatus()
  }
  if (!parsed || typeof parsed !== "object") return emptyStatus()
  return {
    ok: parsed.ok !== false,
    enabled: parsed.enabled === true,
    sink: String(parsed.sink || "omarchy_multi_output"),
    slaves: Array.isArray(parsed.slaves) ? parsed.slaves.map(String) : [],
    previousDefault: String(parsed.previousDefault || ""),
    available: Array.isArray(parsed.available) ? parsed.available : []
  }
}

function selectedCount(status) {
  var available = status && status.available ? status.available : []
  var n = 0
  for (var i = 0; i < available.length; i++) {
    if (available[i] && available[i].selected) n++
  }
  return n
}

function selectedLabels(status) {
  var available = status && status.available ? status.available : []
  var labels = []
  for (var i = 0; i < available.length; i++) {
    var row = available[i]
    if (!row || !row.selected) continue
    labels.push(String(row.description || row.name || "Output"))
  }
  return labels
}

function heroMeta(status) {
  if (!status || !status.ok) return "Audio graph unavailable"
  var labels = selectedLabels(status)
  if (status.enabled && labels.length >= 2) return labels.join(" + ")
  if (labels.length >= 2) return "Ready · " + labels.length + " outputs"
  if (labels.length === 1) return "Pick one more output"
  return "Pick two or more outputs"
}

function barLabel(status) {
  if (!status || !status.enabled) return ""
  var n = selectedCount(status)
  return n >= 2 ? String(n) : ""
}

function tooltip(status) {
  if (status && status.enabled) {
    var labels = selectedLabels(status)
    if (labels.length) return "Playing on " + labels.join(" + ")
    return "omarchy-multi-output on"
  }
  return "Play on several outputs at once"
}

if (typeof module !== "undefined") {
  module.exports = {
    emptyStatus: emptyStatus,
    parseStatus: parseStatus,
    selectedCount: selectedCount,
    selectedLabels: selectedLabels,
    heroMeta: heroMeta,
    barLabel: barLabel,
    tooltip: tooltip
  }
}

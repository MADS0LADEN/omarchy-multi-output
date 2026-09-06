var MAX_BYTES = 65536
var MAX_OUTPUTS = 24
var MAX_LABEL = 80
var MAX_NAME = 256
var SINK_NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/

function validSinkName(name) {
  var text = String(name || "")
  if (text === "." || text === "..") return false
  if (text.length > MAX_NAME) return false
  return SINK_NAME_RE.test(text)
}

function plain(value, limit) {
  var cap = limit === undefined ? MAX_LABEL : limit
  var text = String(value || "")
  var out = ""
  for (var i = 0; i < text.length && out.length < cap; i++) {
    var code = text.charCodeAt(i)
    var ch = text.charAt(i)
    if (ch === "<" || ch === ">" || ch === "&") continue
    if (code < 32 || code === 127 || (code >= 0x80 && code <= 0x9F)) continue
    if ((code >= 0x202A && code <= 0x202E) || (code >= 0x2066 && code <= 0x2069)) continue
    out += ch
  }
  return out
}

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

function parseOutputRow(row, selectedSet) {
  if (!row || typeof row !== "object") return null
  var name = String(row.name || "")
  if (!validSinkName(name)) return null
  var selected = row.selected === true || selectedSet[name] === true
  return {
    name: name,
    description: plain(row.description || name),
    selected: selected
  }
}

function parseStatus(raw) {
  var text = String(raw || "")
  if (!text || text.length > MAX_BYTES) return emptyStatus()
  try {
    var parsed = JSON.parse(text)
  } catch (e) {
    return emptyStatus()
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return emptyStatus()
  if (parsed.ok === false) return emptyStatus()
  var slaves = Array.isArray(parsed.slaves) ? parsed.slaves : []
  if (slaves.length > MAX_OUTPUTS) return emptyStatus()
  var selectedSet = Object.create(null)
  var cleanSlaves = []
  for (var i = 0; i < slaves.length; i++) {
    if (typeof slaves[i] !== "string" || !validSinkName(slaves[i])) return emptyStatus()
    cleanSlaves.push(slaves[i])
    selectedSet[slaves[i]] = true
  }
  var availableIn = Array.isArray(parsed.available) ? parsed.available : []
  if (availableIn.length > MAX_OUTPUTS) return emptyStatus()
  var available = []
  for (var j = 0; j < availableIn.length; j++) {
    var row = parseOutputRow(availableIn[j], selectedSet)
    if (!row) return emptyStatus()
    available.push(row)
  }
  var previous = String(parsed.previousDefault || "")
  if (previous && !validSinkName(previous)) previous = ""
  var sink = String(parsed.sink || "omarchy_multi_output")
  if (sink && !validSinkName(sink)) sink = "omarchy_multi_output"
  return {
    ok: parsed.ok !== false,
    enabled: parsed.enabled === true,
    sink: sink,
    slaves: cleanSlaves,
    previousDefault: previous,
    available: available
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
    labels.push(plain(row.description || row.name || "Output"))
  }
  return labels
}

function heroMeta(status) {
  if (!status || !status.ok) return "Audio graph unavailable"
  var labels = selectedLabels(status)
  if (status.enabled && labels.length >= 2) return plain(labels.join(" + "), 120)
  if (labels.length >= 2) return "Ready · " + labels.length + " outputs"
  if (labels.length === 1) return "Pick one more output"
  return "Pick two or more outputs"
}

function barLabel(status) {
  var n = selectedCount(status)
  if (n > 0) return String(n)
  return ""
}

function tooltip(status) {
  if (status && status.enabled) {
    var labels = selectedLabels(status)
    if (labels.length) return plain("Playing on " + labels.join(" + "), 160)
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
    tooltip: tooltip,
    plain: plain,
    validSinkName: validSinkName
  }
}

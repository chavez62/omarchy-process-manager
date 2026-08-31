.pragma library

function filtered(processes, query, sortKey, descending) {
  var needle = String(query || "").trim().toLowerCase()
  var rows = []
  for (var i = 0; i < (processes || []).length; i++) {
    var process = processes[i]
    if (needle !== "" && String(process.name + " " + process.command + " " + process.pid).toLowerCase().indexOf(needle) === -1)
      continue
    rows.push(process)
  }
  rows.sort(function(a, b) {
    var av = sortValue(a, sortKey)
    var bv = sortValue(b, sortKey)
    var result = typeof av === "string" ? av.localeCompare(bv) : av - bv
    if (result === 0) result = a.pid - b.pid
    return descending ? -result : result
  })
  return rows
}

function sortValue(process, key) {
  if (key === "memory") return Number(process.memory || 0)
  if (key === "name") return String(process.name || "").toLowerCase()
  if (key === "pid") return Number(process.pid || 0)
  return Number(process.cpu || 0)
}

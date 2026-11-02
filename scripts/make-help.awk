/^# help-group: / {
  group = substr($0, 15)
  next
}

/^[a-zA-Z0-9_-]+:.*## / {
  line = $0
  sub(/:.*## /, "  ", line)
  if (!(group in seen)) {
    order[++count] = group
    seen[group] = 1
  }
  entries[group] = entries[group] "  " line "\n"
}

END {
  for (i = 1; i <= count; i++) {
    group = order[i]
    if (i > 1) printf "\n"
    printf "%s\n%s", group, entries[group]
  }
}

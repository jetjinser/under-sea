# Helpers shared by package verification scripts.

verify_store_path_from_output() {
  awk '
    /^\/gnu\/store\/[^[:space:]]+$/ && $0 !~ /\.drv$/ { path = $0 }
    END {
      if (path == "")
        exit 1
      print path
    }
  '
}

#!/usr/bin/env bash

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

hybrid_ai_linux_gpu_note() {
  printf '%s\n' "$1"
}

hybrid_ai_linux_gpu_fail() {
  printf 'ERROR: %s\n' "$1" >&2
  return 1
}

hybrid_ai_linux_gpu_append_unique() {
  local value="$1"
  shift
  local existing

  for existing in "$@"; do
    if [[ "$existing" == "$value" ]]; then
      return 0
    fi
  done

  return 1
}

hybrid_ai_linux_gpu_join_by() {
  local delimiter="$1"
  shift || true
  local first=1
  local value

  for value in "$@"; do
    if [[ $first -eq 1 ]]; then
      printf '%s' "$value"
      first=0
    else
      printf '%s%s' "$delimiter" "$value"
    fi
  done
  printf '\n'
}

hybrid_ai_linux_gpu_collect_device_nodes() {
  local -n out_ref=$1
  local path

  out_ref=()

  if compgen -G '/dev/dri/renderD*' >/dev/null 2>&1; then
    while IFS= read -r path; do
      out_ref+=("$path")
    done < <(compgen -G '/dev/dri/renderD*' | sort)
  fi

  if [[ -e /dev/nvidiactl ]]; then
    out_ref+=("/dev/nvidiactl")
  fi

  if compgen -G '/dev/nvidia[0-9]*' >/dev/null 2>&1; then
    while IFS= read -r path; do
      if ! hybrid_ai_linux_gpu_append_unique "$path" "${out_ref[@]}"; then
        out_ref+=("$path")
      fi
    done < <(compgen -G '/dev/nvidia[0-9]*' | sort)
  fi
}

hybrid_ai_linux_gpu_collect_icd_files() {
  local -n out_ref=$1
  local candidate
  local -a search_dirs
  local -a configured_files

  out_ref=()

  if [[ -n "${VK_ICD_FILENAMES:-}" ]]; then
    IFS=':' read -r -a configured_files <<< "$VK_ICD_FILENAMES"
    for candidate in "${configured_files[@]}"; do
      if [[ -f "$candidate" ]]; then
        out_ref+=("$candidate")
      fi
    done
    return 0
  fi

  search_dirs=(
    /run/opengl-driver/share/vulkan/icd.d
    /etc/vulkan/icd.d
    /usr/local/share/vulkan/icd.d
    /usr/share/vulkan/icd.d
  )

  for candidate in "${search_dirs[@]}"; do
    if [[ -d "$candidate" ]] && compgen -G "$candidate/*.json" >/dev/null 2>&1; then
      while IFS= read -r path; do
        if ! hybrid_ai_linux_gpu_append_unique "$path" "${out_ref[@]}"; then
          out_ref+=("$path")
        fi
      done < <(compgen -G "$candidate/*.json" | sort)
    fi
  done
}

hybrid_ai_linux_gpu_extract_library_paths() {
  local icd_file="$1"
  sed -n 's/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$icd_file"
}

hybrid_ai_linux_gpu_resolve_vendor_library() {
  local library_path="$1"
  local icd_file="$2"
  local icd_dir
  local resolved
  local search_dir
  local -a common_dirs

  if [[ -z "$library_path" ]]; then
    return 1
  fi

  if [[ "$library_path" = /* ]]; then
    if [[ -f "$library_path" ]]; then
      printf '%s\n' "$library_path"
      return 0
    fi
    return 1
  fi

  icd_dir="$(cd "$(dirname "$icd_file")" && pwd)"
  if [[ "$library_path" == */* ]] && [[ -f "$icd_dir/$library_path" ]]; then
    printf '%s\n' "$icd_dir/$library_path"
    return 0
  fi

  if command -v ldconfig >/dev/null 2>&1; then
    resolved="$(ldconfig -p 2>/dev/null | awk -v lib="$library_path" '$1 == lib { print $NF; exit }')"
    if [[ -n "$resolved" ]] && [[ -f "$resolved" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  common_dirs=(
    /usr/lib64
    /usr/lib
    /usr/lib/x86_64-linux-gnu
    /lib64
    /lib
    /lib/x86_64-linux-gnu
  )

  for search_dir in "${common_dirs[@]}"; do
    if [[ -f "$search_dir/$library_path" ]]; then
      printf '%s\n' "$search_dir/$library_path"
      return 0
    fi
  done

  return 1
}

hybrid_ai_linux_gpu_contract_check() {
  local -a device_nodes
  local -a icd_files
  local -a resolved_libraries
  local -a raw_library_paths
  local icd_file
  local library_path
  local resolved_path

  if [[ "$(uname -s)" != "Linux" ]]; then
    hybrid_ai_linux_gpu_fail 'linux GPU contract checks are only supported on Linux'
    return 1
  fi

  hybrid_ai_linux_gpu_collect_device_nodes device_nodes
  if [[ ${#device_nodes[@]} -eq 0 ]]; then
    hybrid_ai_linux_gpu_fail 'missing GPU device visibility; no /dev/dri/renderD* or /dev/nvidia* nodes were found'
    return 1
  fi

  hybrid_ai_linux_gpu_collect_icd_files icd_files
  if [[ ${#icd_files[@]} -eq 0 ]]; then
    hybrid_ai_linux_gpu_fail 'missing Vulkan ICD registration; no ICD JSON files were found'
    return 1
  fi

  raw_library_paths=()
  for icd_file in "${icd_files[@]}"; do
    while IFS= read -r library_path; do
      if [[ -n "$library_path" ]]; then
        raw_library_paths+=("$library_path")
      fi
    done < <(hybrid_ai_linux_gpu_extract_library_paths "$icd_file")
  done

  if [[ ${#raw_library_paths[@]} -eq 0 ]]; then
    hybrid_ai_linux_gpu_fail 'missing Vulkan ICD library_path entries; the discovered ICD JSON files do not point at vendor libraries'
    return 1
  fi

  resolved_libraries=()
  for icd_file in "${icd_files[@]}"; do
    while IFS= read -r library_path; do
      [[ -n "$library_path" ]] || continue
      resolved_path="$(hybrid_ai_linux_gpu_resolve_vendor_library "$library_path" "$icd_file")" || {
        hybrid_ai_linux_gpu_fail "unresolved Vulkan vendor library '$library_path' referenced by $icd_file"
        return 1
      }
      if ! hybrid_ai_linux_gpu_append_unique "$resolved_path" "${resolved_libraries[@]}"; then
        resolved_libraries+=("$resolved_path")
      fi
    done < <(hybrid_ai_linux_gpu_extract_library_paths "$icd_file")
  done

  export HYBRID_AI_GPU_DEVICE_NODES="$(hybrid_ai_linux_gpu_join_by ':' "${device_nodes[@]}")"
  export HYBRID_AI_GPU_ICD_FILES="$(hybrid_ai_linux_gpu_join_by ':' "${icd_files[@]}")"
  export HYBRID_AI_GPU_VENDOR_LIBRARIES="$(hybrid_ai_linux_gpu_join_by ':' "${resolved_libraries[@]}")"

  hybrid_ai_linux_gpu_note "gpu_device_nodes=$HYBRID_AI_GPU_DEVICE_NODES"
  hybrid_ai_linux_gpu_note "gpu_icd_files=$HYBRID_AI_GPU_ICD_FILES"
  hybrid_ai_linux_gpu_note "gpu_vendor_libraries=$HYBRID_AI_GPU_VENDOR_LIBRARIES"
}

hybrid_ai_linux_gpu_apply_bridge_env() {
  if [[ -z "${HYBRID_AI_GPU_ICD_FILES:-}" ]]; then
    hybrid_ai_linux_gpu_contract_check || return 1
  fi

  export VK_ICD_FILENAMES="$HYBRID_AI_GPU_ICD_FILES"
}

hybrid_ai_linux_gpu_print_env() {
  if [[ -z "${HYBRID_AI_GPU_ICD_FILES:-}" ]]; then
    hybrid_ai_linux_gpu_contract_check || return 1
  fi

  printf 'VK_ICD_FILENAMES=%s\n' "$HYBRID_AI_GPU_ICD_FILES"
}

hybrid_ai_linux_gpu_contract_main() {
  set -euo pipefail

  case "${1:-check}" in
    check)
      hybrid_ai_linux_gpu_contract_check
      printf 'linux_gpu_contract=ok\n'
      ;;
    print-env)
      hybrid_ai_linux_gpu_print_env
      ;;
    *)
      printf 'usage: %s [check|print-env]\n' "$0" >&2
      return 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  hybrid_ai_linux_gpu_contract_main "$@"
fi
#!/bin/bash
# ============================================================
# project.sh — Project Runners & Dashboard
# ============================================================

opdb() {
	kp 5051
 cn 51 b "=============================================="
 cn 244 b "🚀 OPENCLAW DASHBOARD 🟥🟧🟨🟩🟦"
    if [ -d "$DASHBOARD_DIR" ]; then
        cn 82 b "🚀 Launching OpenClaw DASHBOARD..."
        cd "$DASHBOARD_DIR"
        if [[ -f "$PYTHON_VENV" ]]; then
	 source "$PYTHON_VENV"
     		 if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
	 printf '%s\n' "$(c 82 b '🚀🔄 Running with PYTHON on ${JOE_ENV} ... 😍')" 
    	 python server.py
         FLASK_PID=$!
         sleep 1.5 && explorer.exe "http://localhost:5051" &
         wait $FLASK_PID
    		  else
  	printf '%s\n' "$(c 82 b '🚀💻 Running with PYTHON3 on ${JOE_ENV} ...😍')"
        python3 server.py
        FLASK_PID=$!
        sleep 1.5 && explorer.exe "http://localhost:5051" &
        wait $FLASK_PID
    		  fi
         fi
     fi

}
opall() {
	# kp() มาจาก system.sh แล้ว ไม่ต้อง define ซ้ำ
	kp 5051
	kp 1111
	kp 2222
	# op1/op2 เป็น optional launchers — ใช้ถ้ามี ไม่มีก็รัน gateway ตรง ๆ
	if command -v op1 >/dev/null 2>&1; then
		op1 && openclaw gateway &
	elif command -v op2 >/dev/null 2>&1; then
		op2 && openclaw gateway &
	else
		openclaw gateway &
	fi
	cn 51 b "=============================================="
	if [ -d "$DASHBOARD_DIR" ]; then
		cn 82 b "🚀 Launching OpenClaw DASHBOARD..."
		cd "$DASHBOARD_DIR"
		if [[ -f "$PYTHON_VENV" ]]; then
			source "$PYTHON_VENV"
			if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
				printf '%s\n' "$(c 82 b '🚀🔄 Running with PYTHON on ${JOE_ENV}...')"
				python server.py
			else
				printf '%s\n' "$(c 82 b '🚀💻 Running with PYTHON3 on ${JOE_ENV}...')"
				python3 server.py
			fi
		fi
	fi
}
tsc() {
    local script_path="$ENGINES_DIR/trend_scan/daily_trend_scan.py"
    if [ -f "$script_path" ]; then
        cn 82 b "🚀 [Trend Scan] Starting..."
        cd "$DASHBOARD_DIR"
        source "$PYTHON_VENV"
        if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
            printf '%s\n' "$(c 82 b '🚀🔄 Running with PYTHON on ${JOE_ENV}...')"
            python "$script_path"
        else
            printf '%s\n' "$(c 82 b '🚀💻 Running with PYTHON3 on ${JOE_ENV}...')"
            python3 "$script_path"
        fi
        cd - > /dev/null
    else
        printf '%s\n' "$(c 196 b '❌ ไม่พบไฟล์ที่: $script_path')"
    fi
}
full_pipe() {
  local niche=${1:-"tech"}
  local tone=${2:-"professional"}
  local max_words=${3:-300}
  local mode=${4:-"full"}
  
    cn 51 b "= 🟥🟧🟨🟩🟦🟩🟨🟧🟥 Full Pipe Line  =============="
    source "$PYTHON_VENV"
    cd "$ENGINES_DIR"
if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
  printf '%s\n' "$(c 82 b '🚀🔄 Running with PYTHON on ${JOE_ENV} ... 😍')" 
    python pipeline_engine.py --niche "$niche" --tone "$tone" --max-words "$max_words" --mode "$mode"
    cn lg b "DONE RUNNING FULL PIPELINE on niche ${niche} with tone ${tone} typing ${max_words} words ,${mode} mode"
else
  printf '%s\n' "$(c 82 b '🚀💻 Running with PYTHON3 on ${JOE_ENV} ...😍')"
   python3 pipeline_engine.py --niche "$niche" --tone "$tone" --max-words "$max_words" --mode "$mode"
    cn lg b "DONE RUNNING FULL PIPELINE on niche ${niche} with tone ${tone} typing ${max_words} words ,${mode} mode"
fi
}
cmdp() {
  case "$JOE_ENV" in
    TERMUX)
        local project="$ENGINES_DIR/cmd-convertor"
        ;;
    *)
        local project="$home/cmd-convertor"
        ;;
  esac      
        source "$PYTHON_VENV"
        cd "$project"
if [[ "$JOE_ENV" == "GIT-BASH" ]]; then
  printf '%s\n' "$(c 82 b '🚀🔄 Running with PYTHON on ${JOE_ENV} ... 😍')" 
    python cli_converter.py
else
  printf '%s\n' "$(c 82 b '🚀💻 Running with PYTHON3 on ${JOE_ENV} ...😍')"

    python3 cli_converter.py

fi
}
pysync() {
    cn 51 b "🔄 Syncing Global Dashboard Python Environment (3.9)..."
    cd "${DASHBOARD_DIR:-$HOME/dashboard}"
    if [ ! -d ".venv" ]; then
        uv venv --python 3.9 .venv
    fi
    uv pip install -r requirements_all.txt
    source "$PYTHON_VENV"
    python3 -m playwright install chromium
    cn 82 b "✅ Python 3.9 environment synced!"
}
 
#--------------PROMPT ENHANCEMENT---------------#
prompt_enhancement() {
  case "$1" in
    cli)
      (cd "$home/logical-enhancement" && source .venv/bin/activate && python3 wizard.py)
      ;;
    gui)
      (
        cd "$home/logical-enhancement" && source .venv/bin/activate
        python3 app.py &
        FLASK_PID=$!
        sleep 1.5 && explorer.exe "http://localhost:5000" &
        wait $FLASK_PID
      )
      ;;
    *)
      echo "Usage: pe [cli|gui]"
      ;;
  esac
}
alias pe='prompt_enhancement'
#--------------------------------------

nx_build() {
  cd "$nx"
  local target="${1:-auto}"
  case "$target" in
    tm|termux)
      NEXUS_ENV=termux bash scripts/build-all.sh "${@:2}"
      ;;
    win|windows)
      NEXUS_ENV=windows bash scripts/build-all.sh "${@:2}"
      ;;
    wsl)
      NEXUS_ENV=windows bash scripts/build-all.sh "${@:2}"
      ;;
    auto)
      # ใช้ JOE_ENV จากระบบ SSOT โดยอัตโนมัติ (ไม่ต้องระบุ argument)
      bash scripts/build-all.sh "${@:2}"
      ;;
    *)
      echo "Usage: nxb [tm|win|wsl|auto] [build-all targets...]"
      echo "  auto  — detect from \$JOE_ENV (current: ${JOE_ENV:-unset})"
      echo "  tm    — force NEXUS_ENV=termux"
      echo "  win   — force NEXUS_ENV=windows"
      echo "  wsl   — force NEXUS_ENV=windows (WSL alias)"
      return 1
      ;;
  esac
}
alias nxb='nx_build'
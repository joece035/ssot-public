#!/bin/bash
#-- load_maneger.sh
#  -- source orch

# -- block-engine loader
_m(){

	_check_ -f 'm' &&
	m "$@"
	
}
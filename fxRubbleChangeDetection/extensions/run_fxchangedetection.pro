;h+
; (c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.
;h-

pro run_fxchangedetection_extensions_init
  compile_opt idl2
  e = envi(/CURRENT)
  e.AddExtension, 'FX Change Detection', 'run_fxchangedetection'
end

pro run_fxchangedetection, event
  compile_opt idl2
  
  ;error catching
  catch, err
  if (err ne 0) then begin
    catch, /CANCEL
    void = dialog_message('Could not perform operation. An error occurred:' + $
      !ERROR_STATE.msg, /ERROR)
    message, /RESET
    return
  endif
  
  ;get current session of ENVI
  e = envi(/CURRENT)
  if (e eq !NULL) then begin
    e = envi()
  endif
  
  ;get the task
  task = ENVITask('fxchangedetection')
  
  ;get parameters
  ok = e.ui.SelectTaskParameters(task)
  if (ok eq 'OK') then begin
    task.execute
  endif
end

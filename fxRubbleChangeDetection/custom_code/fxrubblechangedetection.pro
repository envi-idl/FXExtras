;h+
; (c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.
;h-



;+
; :Description:
;    Procedure which performs change detection based on two images
;    using feature extraction. The approach finds segments in time 1 and
;    then identifues regions that have the highest mean sobel filter values.
;    These regions with high sobel means should then correlate to areas
;    where there is a lot of texture when there was not in the first scene.
;    
;    This approach is ideal for finding houses that turned to rubble after a 
;    tornado or earthquake.
;
;
;
; :Keywords:
;    PERFORM_INTERSECT: in, optional, type=boolean
;      Set this keyword to perform the isntersect of the two images. Required if the
;      datasets don't have the same extent.
;    MIN_SIZE: in, optional, type=number, units=meters^2||pixels
;      Specify the minimum allowed size for segments. Should potentially be set to 
;      larger values. Assumed units are meters^2 if spatial reference is present, 
;      otherwise hte units represent number of pixels.
;    SEGMENT_VALUE: in, optional, type=number
;      Specify the segment value used for Feature Extraction. See FX docs for more info.
;    MERGE_VALUE: in, optional, type=number
;      Specify the merge value used for Feature Extraction. See FX docs for more info.
;    TIME1_RASTER: in, required, type=ENVIRaster
;      Specify the first scene for change detection - this one is segmented with FX.
;    TIME2_RASTER: in, required, type=ENVIRaster
;      Specify the second scene for change detection - this one is used for sobel means.
;    MASK_VEGETATION_AND_WATER: in, optional, type=boolean
;      If set, then a basic vegetation and water mask is applied to the scene. Only applied
;      if you have the bands necessary to calculate an NDVI.
;    SHADOW_THRESHOLD: in, optional, type=number
;      Specify the lowest pixel value to be considered for processing. This helps remove
;      shadows which can be areas of false rubble detection if time of day and viewing
;      angles change between scenes.
;    OUTPUT_RASTER_URI: in, optional, type=string, default=temporary filename
;      optionally specify the output filename for the output raster. If not set, ENVI will
;      pick a temporary file.
;
; :Author: Zachary Norman - GitHub: znorman-harris
;-
pro fxRubbleChangeDetection, $
  PERFORM_INTERSECT = perform_intersect,$
  MIN_SIZE = min_size, $
  SEGMENT_VALUE = segment_value, $
  MERGE_VALUE = merge_value, $
  TIME1_RASTER = time1_raster, $
  TIME2_RASTER = time2_raster, $
  MASK_VEGETATION_AND_WATER = mask_vegetation_and_water,$
  SHADOW_THRESHOLD = shadow_threshold,$
  OUTPUT_RASTER_URI = output_raster_uri
  compile_opt idl2, hidden

  ;check for current session of ENVI
  e = envi(/CURRENT)
  if (e eq !NULL) then begin
    e = envi(/HEADLESS)
  endif

  catch, err
  if (err ne 0) then begin
    catch, /CANCEL
    message, /REISSUE_LAST
  endif

  ;make sure that our rasters have the same dimensions
  dims1 = [time1_raster.NCOLUMNS, time1_raster.NROWS]
  dims2 = [time2_raster.NCOLUMNS, time2_raster.NROWS]

  ;make sure they are the same (doesn't mean that they intersect, but it is a good safety check
  if ~array_equal(dims1, dims2) AND ~keyword_set(PERFORM_INTERSECT) then begin
    message, 'Images do not have the same dimensions and the PERFORM_INTERSECT option was not set. Cannot proceed'
  endif else begin
    ;we can intersect, so lets intersect
    if ~array_equal(dims1, dims2) then begin
      ;use virtual rasters so that our scenes cover the same area
      ;don't need to worry about valid pixels, 
      virtualRasterIntersection, $
        INPUT_RASTER1 = time1_raster, $
        INPUT_RASTER2 = time2_raster, $
        OUTPUT_RASTER1 = time1,$
        OUTPUT_RASTER2 = time2
    endif else begin
      ;we don't need to intersect, so we can just update variable names
      time1 = time1_raster
      time2 = time2_raster
    endelse
  endelse
  
  ;check if we want to ignore vegetation and water
  if keyword_set(mask_vegetation_and_water) then begin
    roi = ENVIROI()
    si1 = ENVISpectralindexRaster(time1, 'NDVI', ERROR = error1)
    if ~keyword_set(error1) then roi.AddThreshold, si1, 0, MIN_VALUE = -0.2, MAX_VALUE = 0.2
    si2 = ENVISpectralindexRaster(time2, 'NDVI', ERROR = error2)
    if ~keyword_set(error1) then roi.AddThreshold, si1, 0, MIN_VALUE = -0.2, MAX_VALUE = 0.2
    
    ;make sure that there have been things added to the ROI
    if (roi.N_DEFINITIONS gt 0) then begin
      roi.save, e.gettemporaryfilename('xml')
      time1Mask = ENVIROIMaskRaster(time1, roi, ERROR = error)
      if ~keyword_set(error) then begin
        time1 = time1Mask
      endif
      time2Mask = ENVIROIMaskRaster(time2, roi, ERROR = error)
      if ~keyword_set(error) then begin
        time2 = time2Mask
      endif
    endif
  endif

  ;check if we have a shadow threshold to mask with
  if (shadow_threshold ne !NULL) then begin
    roi = ENVIROI()
    for i=0, time1.NBANDS-1 do roi.AddThreshold, time1, i, MAX_VALUE = shadow_threshold
    for i=0, time2.NBANDS-1 do roi.AddThreshold, time2, i, MAX_VALUE = shadow_threshold
    roi.save, e.GetTemporaryFilename('xml')
    time1Mask = ENVIROIMaskRaster(time1, roi, /INVERSE, ERROR = error)
    if ~keyword_set(error) then begin
      time1 = time1Mask
    endif
    time2Mask = ENVIROIMaskRaster(time2, roi, /INVERSE, ERROR = error)
    if ~keyword_set(error) then begin
      time2 = time2Mask
    endif
  endif

  ;export our virtual rasters to disk to save processing time with FX
  out = e.GetTemporaryFilename()
  time1.export, out, 'ENVI', DATA_IGNORE_VALUE = 0
  time1 = e.openRaster(out)
  
  out = e.GetTemporaryFilename()
  time2.export, out, 'ENVI', DATA_IGNORE_VALUE = 0
  time2 = e.openRaster(out)

  ;perform FX on our raster
  fxTask = ENVITask('FXSegmentation')
  fxTask.INPUT_RASTER = time1
  fxTask.SEGMENT_VALUE = segment_value
  fxTask.MERGE_VALUE = merge_value
  fxTask.execute
  fx_raster = fxTask.OUTPUT_RASTER
  
  ;calculate bandmath on our datasets
;  stack = ENVIMetaspectralRaster([ENVISubsetRaster(time1, BANDS = [0]), ENVISubsetRaster(time2, BANDS = [0])], SPATIALREF = time2.SPATIALREF)
;  math = ENVISubsetRaster(ENVIRankStrengthTextureRaster(ENVIPixelwiseBandmathRaster(stack, 'fix(b2) - fix(b1)')),BANDS = 0)
  
  ;determine the metric for change
  math = ENVIPixelwiseBandMathRaster(time2, 'sobel(b1)')
  
  ;get sobel information
  statsTask = ENVITask('GetFXRasterStats')
  statsTask.FX_RASTER = fx_raster
  statsTask.BUFFER = 1
  statsTask.STATS_RASTER = math
  statsTask.execute
  sobelStats = statsTask.OUTPUT_STATS
  
  ;mask segment size for our scene
  maskTask = ENVITask('MaskFXRasterStats')
  maskTask.INPUT_STATS = sobelStats
  maskTask.SIZE_MIN = min_size
  maskTask.execute
  sobelMaskedStats = maskTask.OUTPUT_STATS

  ;convert our means to int to save on file size
  sobelMaskedStats['MEANS'] = fix(sobelMaskedStats['MEANS'])
  
  ;create a raster of our FX statistics
  rasterizeTask = ENVITask('RasterizeFXRasterStats')
  rasterizeTask.FX_RASTER = fx_raster
  rasterizeTask.INPUT_STATS = sobelMaskedStats
  rasterizeTask.RASTERIZE_STATS = ['mean']
  rasterizeTask.execute
  
  ;get references to our masked raster
  maskRaster = rasterizeTask.OUTPUT_MASK_RASTER
  meanRaster = rasterizeTask.OUTPUT_MEAN_RASTER

  ;mask our raster and export to disk
  maskedRaster = ENVIMaskRaster(meanRaster, maskRaster)
  maskedRaster.export, output_raster_uri, 'ENVI', DATA_IGNORE_VALUE = 0
  maskedRaster.close
  maskRaster.close
  output_raster = e.openRaster(output_raster_uri)
end
;h+
; (c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.
;h-

;+
; :Description:
;    Procedure that creates rasters from statistics extracted via gstFXRasterStats.
;
;
;
; :Keywords:
;    FX_RASTER: in, required, type=ENVIRaster
;      Specify the source FX raster (used for correctly positioning the segments)
;    INPUT_STATS: in, reuiqred, type=orderedhash
;      Specify the stats calculated by getFXRasterStats
;    OUTPUT_MASK_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;      Specify the output filename for the output mask raster. If not specified then a
;      temporary filename will be used.
;    OUTPUT_MIN_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;    Specify the output filename for the output segment minimum raster. If not specified then a
;      temporary filename will be used.
;    OUTPUT_MAX_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;    Specify the output filename for the output segment maximum raster. If not specified then a
;      temporary filename will be used.
;    OUTPUT_MEAN_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;    Specify the output filename for the output segment mean raster. If not specified then a
;      temporary filename will be used.
;    OUTPUT_TOTAL_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;    Specify the output filename for the output segment total raster. If not specified then a
;      temporary filename will be used.
;    OUTPUT_COUNT_RASTER_URI: in, optional, type=string, default=ENVI temporary file
;    Specify the output filename for the output segmenet number of pixels raster. If not specified then a
;      temporary filename will be used.
;    RASTERIZE_STATS: in, requried, type=string/stringarr
;      Specify the names of the statistics that you want to generate rasters for. Options are:
;      min, max, mean, total, or count.
;
; :Author: Zachary Norman - GitHub: znorman-harris
;-
pro rasterizeFxRasterStats,$
  FX_RASTER = fx_raster,$
  INPUT_STATS = input_stats,$
  OUTPUT_MASK_RASTER_URI = output_mask_raster_uri,$
  OUTPUT_MIN_RASTER_URI = output_min_raster_uri,$
  OUTPUT_MAX_RASTER_URI = output_max_raster_uri,$
  OUTPUT_MEAN_RASTER_URI = output_mean_raster_uri,$
  OUTPUT_TOTAL_RASTER_URI = output_total_raster_uri,$
  OUTPUT_COUNT_RASTER_URI = output_count_raster_uri,$
  RASTERIZE_STATS = rasterize_stats
  compile_opt idl2

  ;get current ENVI session
  e = envi(/CURRENT)

  ;make sure our inputs are valid
  if (fx_raster.NBANDS ne 1) then begin
    message, 'FX_RASTER does not have one band, required!'
  endif
  if ~isa(input_stats, 'hash') then begin
    message, 'STATS is not a valid hash object. Has it been specified?'
  endif

  catch, err
  if (err ne 0) then begin
    catch, /CANCEL
    message, /REISSUE_LAST
  endif

  ;get the data from our stats hash
  totals = input_stats['TOTALS']
  counts = input_stats['COUNTS']
  mins = input_stats['MINS']
  maxs = input_stats['MAXS']
  means = input_stats['MEANS']
  validData = input_stats['VALID_DATA']
  statsRaster = input_stats['RASTER']
  metadata = statsRaster.METADATA
  bandNames = metadata['band names']

  ;get the number of bands for our stats raster
  nBands = n_elements(bandNames)
  dims = [fx_raster.NCOLUMNS, fx_raster.NROWS]
  bandPixels = ulong64(dims[0])*dims[1]

  ;init object to store the stats rasters for us
  output_stats_rasters = dictionary()
  
  ;figure out what stats we want to rasterize
  foreach statsName, strlowcase(rasterize_stats) do begin
    case (statsName) of
      'min':begin
        meta = ENVIRasterMetadata()
        meta['band names'] = 'FX Segment Mins : ' + bandNames
        if metadata.hasTag('wavelength') AND metadata.hasTag('wavelength units') then begin
          meta['wavelength'] = metadata['wavelength']
          meta['wavelength units'] = metadata['wavelength units']
        endif
        output_stats_rasters['mins'] = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = nBands, DATA_TYPE = mins.TYPECODE, SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_min_raster_uri)
      end
      'max':begin
        meta = ENVIRasterMetadata()
        meta['band names'] = 'FX Segment Maxs : ' + bandNames
        if metadata.hasTag('wavelength') AND metadata.hasTag('wavelength units') then begin
          meta['wavelength'] = metadata['wavelength']
          meta['wavelength units'] = metadata['wavelength units']
        endif
        output_stats_rasters['maxs'] = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = nBands, DATA_TYPE = maxs.TYPECODE, SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_max_raster_uri)
      end
      'mean':begin
        meta = ENVIRasterMetadata()
        meta['band names'] = 'FX Segment Means : ' + bandNames
        if metadata.hasTag('wavelength') AND metadata.hasTag('wavelength units') then begin
          meta['wavelength'] = metadata['wavelength']
          meta['wavelength units'] = metadata['wavelength units']
        endif
        output_stats_rasters['means'] = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = nBands, DATA_TYPE = means.TYPECODE, SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_mean_raster_uri)
      end
      'total':begin
        meta = ENVIRasterMetadata()
        meta['band names'] = 'FX Segment Totals : ' + bandNames
        if metadata.hasTag('wavelength') AND metadata.hasTag('wavelength units') then begin
          meta['wavelength'] = metadata['wavelength']
          meta['wavelength units'] = metadata['wavelength units']
        endif
        output_stats_rasters['totals'] = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = nBands, DATA_TYPE = totals.TYPECODE, SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_total_raster_uri)
      end
      'count':begin
        meta = ENVIRasterMetadata()
        meta['band names'] = 'FX Segment Counts : ' + bandNames
        output_stats_rasters['counts'] = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = 1, DATA_TYPE = counts.TYPECODE, SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_count_raster_uri)
      end
      else:;do nothing
    endcase
  endforeach
  
  ;make sure that we have a stat that we want to rasterize
  if (n_elements(output_stats_rasters) eq 0) then begin
    message, 'No entries in RASTERIZE_STATS match the choice list!'
  endif

  ;create a masked raster
  meta = ENVIRasterMetadata()
  meta['band names'] = 'FX Segment Mask'
  meta['classes'] = 2
  meta['class names'] =  ['Masked', 'Process']
  meta['class lookup'] = [[0,0,0],[255,255,255]]
  maskRaster = ENVIRaster(NCOLUMNS = dims[0], NROWS = dims[1], NBANDS = 1, DATA_TYPE = 'byte', SPATIALREF = fx_raster.SPATIALREF, METADATA = meta, URI = output_mask_raster_uri)

  ;make our tiles
  createBetterTileIterator,$
    INPUT_RASTER = fx_raster,$
    OUTPUT_SUB_RECTS = sub_rects

  ;loop over each tile
  foreach sub, sub_rects, z do begin
    ;get the label sub rect
    fxDatSub = fx_raster.getData(PIXEL_STATE = tileMask, SUB_RECT = sub)
    
    ;zero our pixel state in the tile mask
    tileMask = temporary(~tileMask)
    
    ;skip if no valid pixels
    if (fxDatSub.max() ge 1) then begin
      ;calculate the histogram
      h = histogram(fxDatSub, MIN = 1, REVERSE_INDICES = r, LOCATIONS = vals)

      ;zero values
      vals--

      ;check to make sure that we have valid segments to process
      idxOk = where(validData[vals], countOk, COMPLEMENT = idxBad, NCOMPLEMENT = countBad)
      if (countBad gt 0) then begin
        foreach i, idxBad do begin
          ;skip if the indices are invalid for our pixel (zero from histogram?)
          if (R[i] eq R[i+1]) then continue

          ;set mask accordingly
          tileMask[R[R[i] : R[i+1]-1]] = 0b
        endforeach
      endif

      ;get the indices of our histogram that have non-zero counts
      idxCount = where(h, countCount)

      ;get the dimensions for our data
      dims = [sub[2] - sub[0] + 1, sub[3] - sub[1] + 1]

      ;loop over each raster
      foreach raster, output_stats_rasters, key do begin
        bPtrs = ptrarr(nBands)

        for j=0, nBands-1 do begin
          ;preallocate an array to populate with values
          case (key) of
            'mins':   bPtrs[j] = ptr_new(make_array(dims[0], dims[1], TYPE = mins.TYPECODE))
            'maxs':   bPtrs[j] = ptr_new(make_array(dims[0], dims[1], TYPE = maxs.TYPECODE))
            'means':  bPtrs[j] = ptr_new(make_array(dims[0], dims[1], TYPE = means.TYPECODE))
            'totals': bPtrs[j] = ptr_new(make_array(dims[0], dims[1], TYPE = totals.TYPECODE))
            'counts': bPtrs[j] = ptr_new(make_array(dims[0], dims[1], TYPE = counts.TYPECODE))
          endcase
        endfor

        ;process each segment only if we have some in this tile
        if (countOk gt 0) AND (countCount gt 0) then begin
          foreach i, idxCount do begin
            ;skip if the indices are invalid for our pixel (zero from histogram?)
            if (R[i] eq R[i+1]) then continue

            ;get the indices
            idxSeg = R[R[i] : R[i+1]-1]

            ;loop over each band and fill output with values
            for j=0, nBands-1 do begin
              ;break if only counts and exit loop
              if (key eq 'counts') then begin
                (*bPtrs[0])[idxSeg] = counts[vals[i]]
                break
              endif

              ;check what else we might be writing to disk
              case (key) of
                'mins':   (*bPtrs[j])[idxSeg] = mins[vals[i], j]
                'maxs':   (*bPtrs[j])[idxSeg] = maxs[vals[i], j]
                'means':  (*bPtrs[j])[idxSeg] = means[vals[i], j]
                'totals': (*bPtrs[j])[idxSeg] = totals[vals[i], j]
              endcase
            endfor
          endforeach
        endif

        ;break if only counts and exit loop
        if (key eq 'counts') then begin
          saveDat = *bPtrs[0]
        endif else begin
          ;preallocate an array to populate with values
          case (key) of
            'mins':   saveDat = make_array(dims[0], dims[1], nBands, TYPE = mins.TYPECODE)
            'maxs':   saveDat = make_array(dims[0], dims[1], nBands, TYPE = maxs.TYPECODE)
            'means':  saveDat = make_array(dims[0], dims[1], nBands, TYPE = means.TYPECODE)
            'totals': saveDat = make_array(dims[0], dims[1], nBands, TYPE = totals.TYPECODE)
          endcase
          for j=0, nBands-1 do saveDat[*,*,j] = *bPtrs[j]
        endelse

        ;write our data to disk
        raster.SetData, saveDat, SUB_RECT = sub
      endforeach
    endif else begin
      ;turn off al l pixels for processing
      tileMask *= 0b
    endelse
    
    ;set the data values for where we are masked or not
    maskRaster.SetData, tileMask, SUB_RECT = sub
  endforeach

  ;save our changes to disk
  foreach raster, output_stats_rasters do raster.save
  
  ;save mask
  maskRaster.save
end
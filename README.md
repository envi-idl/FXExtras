# Feature Extraction Extras (FXExtras)

This collection of tasks contains some useful tools that can add ease-of-use to ENVI's feature extraction (FX) module and allow for custom processing and thresholding of the results. Specifically the tools allow you to:

1. Identifying rubble using feature extraction and change detection (FXRubbleChangeDetection). This algorithm was developed identifying rubble from where tornadoes have destroyed homes. It might also work well with earthquake imagery where buildings have collapsed and are now rubble. It is not optimized for hurricane damage. **Note that high resolution imagery is required to effectively run this tool. Pixels should be 0.5 meter or smaller for the time 2 image.**

2. Extract statistics from the regions determined using FX (GetFXRasterStats).

3. Mask those statistics with basic logic conditions (MaskFXRasterStats).

4. Create a raster from the calculated statistics (RasterizeFXRasterStats).

## Requirements

You will need ENVI + IDL to run this code, as well as the Feature Extraction module for ENVI.

## Installation

You will need to place all PRO code and task files in ENVI's custom code folder. For notes on where you can do this, see the following link:

[https://github.com/envi-idl/TaskAndExtensionInstallGuide](https://github.com/envi-idl/TaskAndExtensionInstallGuide)

# Examples

Here are some examples for how to run the tasks mentioned above, note that most of these are meant to be used together.

See the source code from `fxrubblechangedetection.pro` for example of how these tasks are used together.

## Example With FXRubbleChangeDetection

This example does require two overlapping scenes to run.

```idl
;start ENVI
e = envi()

;open our data
time1 = e.openRaster('C:\time1\raster.dat')
time2 = e.openRaster('C:\time2\raster.dat')

;create our task object
fxTask = ENVITask('FXRubbleChangeDetection')
fxTask.TIME1_RASTER = time1
fxTask.TIME2_RASTER = time2
fxTask.MIN_SIZE = 20 ;assumed to be square meters, otherwise pixels if no spatialref
fxTask.SHADOW_THRESHOLD = 100
fxTask.MASK_VEGETATION_AND_WATER = 1
fxTask.PERFORM_INTERSECT = 1
fxTask.execute

;add our raster to ENVI's data collection
e.data.add, fxTask.OUTPUT_RASTER

;display our rasters in ENVI
view = e.getView()
layer1 = view.createLayer(time1, /CLEAR_DISPLAY)
layer2 = view.createLayer(time2)
layer3 = view.createLayer(fxTask.OUTPUT_RASTER)
```


## Example with GetFXRasterStats and RasterizeFXRasterStats

You can copy/paste this code into IDL after ENVI is aware of the tasks.

```idl
;start ENVI
e = envi()

; open a sample raster
file = filePath('qb_boulder_msi', SUBDIR = ['data'], $
  ROOT_DIR = e.ROOT_DIR)
raster = e.openRaster(File)

;segment our image
segmentTask = ENVITask('FXSegmentation')
segmentTask.INPUT_RASTER = raster
segmentTask.execute

;add result to ENVI's data collection
e.data.add, segmentTask.OUTPUT_RASTER

;get statistics on RGB values for each segment
statsTask = ENVITask('GetFXRasterStats')
statsTask.FX_RASTER = segmentTask.OUTPUT_RASTER
statsTask.BUFFER = 1
statsTask.STATS_RASTER = ENVISubsetRaster(raster, BANDS = [0,1,2])
statsTask.execute

;create a raster of our FX statistics
rasterizeTask = ENVITask('RasterizeFXRasterStats')
rasterizeTask.FX_RASTER = segmentTask.OUTPUT_RASTER
rasterizeTask.INPUT_STATS = statsTask.OUTPUT_STATS
rasterizeTask.RASTERIZE_STATS = ['mean']
rasterizeTask.execute

;add result to ENVI's data collection
e.data.add, rasterizeTask.OUTPUT_MEAN_RASTER

;display our rasters in ENVI
view = e.getView()
layer1 = view.createLayer(raster, /CLEAR_DISPLAY)
layer2 = view.createLayer(segmentTask.OUTPUT_RASTER)
layer3 = view.createLayer(rasterizeTask.OUTPUT_MEAN_RASTER)
```


## Example with GetFXRasterStats, RasterizeFXRasterStats, and MaskFXRasterStats

This example creates a water mask on the sample dataset.

You can copy/paste this code into IDL after ENVI is aware of the tasks.

```idl
;start ENVI
e = envi()

; open a sample raster
file = filePath('qb_boulder_msi', SUBDIR = ['data'], $
  ROOT_DIR = e.ROOT_DIR)
raster = e.openRaster(File)

;segment our image
segmentTask = ENVITask('FXSegmentation')
segmentTask.INPUT_RASTER = raster
segmentTask.execute

;add result to ENVI's data collection
e.data.add, segmentTask.OUTPUT_RASTER

;get statistics on RGB values for each segment
statsTask = ENVITask('GetFXRasterStats')
statsTask.FX_RASTER = segmentTask.OUTPUT_RASTER
statsTask.BUFFER = 1
statsTask.STATS_RASTER = ENVISubsetRaster(raster, BANDS = [0,1,2])
statsTask.execute

;mask our stats by size and maximum pixel value
maskStatsTask = ENVITask('MaskFXRasterStats')
maskStatsTask.INPUT_STATS = statsTask.OUTPUT_STATS
maskStatsTask.MEAN_MAX = 275
maskStatsTask.SIZE_MIN = 400 ;assumed as square meters if spetial reference, otherwise pixels
maskStatsTask.execute

;conver the type of our stats to integer reduce output file size
;output data type is taken from the stats which are calculated using doubles
maskStatsTask.OUTPUT_STATS['MEANS'] = fix(maskStatsTask.OUTPUT_STATS['MEANS'])

;create a raster of our FX statistics
rasterizeTask = ENVITask('RasterizeFXRasterStats')
rasterizeTask.FX_RASTER = segmentTask.OUTPUT_RASTER
rasterizeTask.INPUT_STATS = maskStatsTask.OUTPUT_STATS
rasterizeTask.RASTERIZE_STATS = ['mean']
rasterizeTask.execute

;add result to ENVI's data collection
e.data.add, rasterizeTask.OUTPUT_MEAN_RASTER
e.data.add, rasterizeTask.OUTPUT_MASK_RASTER

;mask our results
masked = ENVIMaskRaster(rasterizeTask.OUTPUT_MEAN_RASTER, rasterizeTask.OUTPUT_MASK_RASTER)
e.data.add, masked

;display our rasters in ENVI
view = e.getView()
layer1 = view.createLayer(raster, /CLEAR_DISPLAY)
layer2 = view.createLayer(segmentTask.OUTPUT_RASTER)
layer3 = view.createLayer(masked) ;will be goofy colors because of stretching
layer4 = view.createLayer(rasterizeTask.OUTPUT_MASK_RASTER)
```

## License

Licensed under MIT. See LICENSE.txt for additional details and information.

(c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.


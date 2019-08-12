"""Diagnostic for WALRUS based on diag_shapeselect.py."""
import logging
import os
from copy import deepcopy

import fiona
import pandas as pd
import iris
import numpy as np
from netCDF4 import Dataset, num2date
from shapely.geometry import MultiPoint, shape
from shapely.ops import nearest_points

from esmvaltool.diag_scripts.shared import (run_diagnostic, ProvenanceLogger,
                                            get_diagnostic_filename)

logger = logging.getLogger(os.path.basename(__file__))


def get_provenance_record(cfg, basename, caption, extension):
    """Create a provenance record describing the diagnostic data and plot."""
    record = {
        'caption': caption,
        'statistics': ['other'],
        'domains': ['global'],
        'authors': ['berg_pe'],
        'references': ['acknow_project'],
    }
    diagnostic_file = get_diagnostic_filename(basename, cfg, extension)
    with ProvenanceLogger(cfg) as provenance_logger:
        provenance_logger.log(diagnostic_file, record)


def shapeselect(cfg, cube):
    """Select data inside a shapefile and do averaging."""
    gjpath = cfg['geojfile']
    if not os.path.isabs(gjpath):
        gjpath = os.path.join(cfg['auxiliary_data_dir'], gjpath)
    wgtmet = cfg['weighting_method']
    if ((cube.coord('latitude').ndim == 1
         and cube.coord('longitude').ndim == 1)):
        coordpoints = [(x, y) for x in cube.coord('longitude').points
                       for y in cube.coord('latitude').points]
        for i, crd in enumerate(coordpoints):
            if crd[0] > 180:
                coordpoints[i] = (coordpoints[i][0] - 360., coordpoints[i][1])
    else:
        raise ValueError("Support for 2-d coords not implemented!")
    points = MultiPoint(coordpoints)
    with fiona.open(gjpath) as shp:
        gpx = []
        gpy = []
        cnt = -1
        ncts = np.zeros((cube.coord('time').shape[0], len(shp)))
        nclon = np.zeros((len(shp)))  # Takes representative point
        nclat = np.zeros((len(shp)))
        for ishp, multipol in enumerate(shp):
            cnt += 1
            multi = shape(multipol['geometry'])
            if wgtmet == 'mean_inside':
                gpx, gpy = mean_inside(gpx, gpy, points, multi, cube)
                if not gpx:
                    gpx, gpy = representative(gpx, gpy, points, multi, cube)
            elif wgtmet == 'representative':
                gpx, gpy = representative(gpx, gpy, points, multi, cube)
            if len(gpx) == 1:
                ncts[:, ishp] = np.reshape(cube.data[:, gpy, gpx],
                                           (cube.data.shape[0], ))
            else:
                ncts[:, ishp] = np.mean(cube.data[:, gpy, gpx], axis=1)
            gxx, gyy = representative([], [], points, multi, cube)
            nclon[ishp] = cube.coord('longitude').points[gxx]
            nclat[ishp] = cube.coord('latitude').points[gyy]
    return ncts


def mean_inside(gpx, gpy, points, multi, cube):
    """Find points inside shape."""
    for point in points:
        if point.within(multi):
            if point.x < 0:
                addx = 360.
            else:
                addx = 0.
            xxx, yyy = best_match(
                cube.coord('longitude').points,
                cube.coord('latitude').points, point.x + addx, point.y)
            gpx.append(xxx)
            gpy.append(yyy)
    return gpx, gpy


def representative(gpx, gpy, points, multi, cube):
    """Find representative point in shape."""
    reprpoint = multi.representative_point()
    nearest = nearest_points(reprpoint, points)
    npx = nearest[1].coords[0][0]
    npy = nearest[1].coords[0][1]
    if npx < 0:
        addx = 360.
    else:
        addx = 0.
    xxx, yyy = best_match(
        cube.coord('longitude').points,
        cube.coord('latitude').points, npx + addx, npy)
    gpx.append(xxx)
    gpy.append(yyy)
    return gpx, gpy


def best_match(iin, jin, pex, pey):
    """Identify the grid points in 2-d with minimum distance."""
    if iin.shape != 2 or jin.shape != 2:
        gpx = deepcopy(iin)
        gpy = deepcopy(jin)
        gpxx = np.zeros((len(gpx), len(gpy)))
        gpyy = np.zeros((len(gpx), len(gpy)))
        for gpi in range(0, len(gpy)):
            gpxx[:, gpi] = gpx
        for gpj in range(0, len(gpx)):
            gpyy[gpj, :] = gpy
    else:
        gpxx = deepcopy(iin)
        gpyy = deepcopy(jin)
    distance = ((gpxx - pex)**2 + (gpyy - pey)**2)**0.5
    ind = np.unravel_index(np.argmin(distance, axis=None), distance.shape)
    return ind[0], ind[1]


def getdata(filename, ncts):
    """get the content of a netcdffile inside the lumped area."""
    ncfile = Dataset(filename, 'r')
    dtime = num2date(ncfile.variables['time'][:],
                     ncfile.variables['time'].units,
                     ncfile.variables['time'].calendar)
    wtime = []
    for dtim in dtime:
        wtime.append(str(dtim))
    wdata = []
    for row in range(ncts.shape[1]):
        wdata.append(np.around(np.squeeze(ncts[:, row]), decimals=8))
    return wtime, wdata


def writdat(cfg, input_dt):
    """Write the content of a dataframe as .dat."""
    input_dt['Q'] = [None]*input_dt.shape[0]
    dtpath = cfg['datfile']
    if not os.path.isabs(dtpath):
        dtpath = os.path.join(cfg['auxiliary_data_dir'], dtpath)
    if os.path.isfile(dtpath):
        dummy_df = pd.read_csv(dtpath, sep=' ')
        if 'Q' in dummy_df.columns:
            input_dt['Q'] = dummy_df['Q']
    input_dt.rename(columns={
                'pr': 'P',
                'evspsblpot': 'ETpot',
                'tas': 'T',
                'rsds': 'GloRad'}, inplace=True)
    dtpath = os.path.join(cfg['work_dir'], '_polygon_table', '.dat')
    input_dt.to_csv(dtpath, index=True, header=True, sep=' ')


def main(cfg):
    """Select grid points within shapefiles."""
    if 'evalplot' not in cfg:
        cfg['evalplot'] = False
    input_dt = pd.DataFrame()
    for filename, attributes in cfg['input_data'].items():
        logger.info("Processing variable %s from dataset %s",
                    attributes['standard_name'], attributes['dataset'])
        logger.debug("Loading %s", filename)
        cube = iris.load_cube(filename)
        ncts = shapeselect(cfg, cube)
        wtime, wdata = getdata(filename, ncts)
        input_dt['date'] = wtime
        input_dt[str(attributes['standard_name'])] = wdata
    name = cfg['model']
    if cfg['write_dat']:
        writdat(cfg, input_dt)
        caption = 'Average value within lumped area.'
        get_provenance_record(cfg, name, caption, 'dat')


if __name__ == '__main__':
    with run_diagnostic() as config:
        main(config)

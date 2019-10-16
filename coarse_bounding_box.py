# -*- coding: utf-8 -*-
import math
import fiona

def coarse_bounding_box(shapefile, degree_buffer=float):
    """ Extract extent from shapefile and add a buffer in degrees."""
    shape = fiona.open(shapefile)
    
    xmin, ymin, xmax, ymax = shape.bounds
    
    xmin_round = math.floor(xmin) - degree_buffer
    xmax_round = math.ceil(xmax)  + degree_buffer
    ymin_round = math.floor(ymin) - degree_buffer
    ymax_round = math.ceil(ymax)  + degree_buffer
    
    print('xmin: ' + str(xmin) + ' -> xmin margin: ' + str(xmin_round))
    print('ymin: ' + str(ymin) + ' -> ymin margin: ' + str(ymin_round))
    print('xmax: ' + str(xmax) + ' -> xmax margin: ' + str(xmax_round))
    print('ymax: ' + str(ymax) + ' -> ymax margin: ' + str(ymax_round))
    
    return xmin_round, ymin_round, xmax_round, ymax_round
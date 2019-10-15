# -*- coding: utf-8 -*-
import math
import fiona

def coarse_bounding_box(shapefile, degree_buffer=float):
    """ Extract extent from shapefile and add a buffer in degrees."""
    shape = fiona.open(shapefile)
    
    xmin, ymin, xmax, ymax = shape.bounds
    
    print('xmin: ' + str(xmin))
    print('xmax: ' + str(xmax))
    print('ymin: ' + str(ymin))
    print('ymax: ' + str(ymax))

    if xmin > 0:
        xmin_round = math.floor(xmin) - degree_buffer
        xmax_round = math.ceil(xmax)  + degree_buffer
    else:
        xmin_round = math.floor(xmin) - degree_buffer
        xmax_round = math.ceil(xmax)  + degree_buffer
        
    if ymin > 0:
        ymin_round = math.floor(ymin) - degree_buffer
        ymax_round = math.ceil(ymax)  + degree_buffer
    else:
        ymin_round = math.floor(ymin) - degree_buffer  
        ymax_round = math.ceil(ymax)  + degree_buffer 
    
    return xmin_round, ymin_round, xmax_round, ymax_round

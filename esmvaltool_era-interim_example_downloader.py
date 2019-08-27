#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Aug 20 14:48:43 2019

@author: jerom
"""

from ecmwfapi import ECMWFDataServer

server = ECMWFDataServer()
    
server.retrieve({
    'stream'    : "oper",
    'levtype'   : "sfc",
    'param'     : "167.128", # "167.128"=temperature, "228.128"=precipitation, "182.128"=evaporation
    'dataset'   : "interim",
    'step'      : "12",
    'grid'      : "0.75/0.75",
    'time'      : "00",
    'date'      : "1979-01-01/to/1979-12-31",
    'type'      : "fc",
    'class'     : "ei",
    'format'    : "netcdf",
    'target'    : "ERA-Interim_daily_1979.nc"
 })

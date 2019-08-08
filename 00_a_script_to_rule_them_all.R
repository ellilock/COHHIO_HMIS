# COHHIO_HMIS
# Copyright (C) 2019  Coalition on Homelessness and Housing in Ohio (COHHIO)
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details at 
#<https://www.gnu.org/licenses/>.

# Run this whenever either one of these scripts has fundamentally changed or the
# data has been refreshed.

# Each script here creates an image file which is then sym linked to both
# R minor and R minor elevated. Running this after updating the data files should
# be all that's necessary in order to be sure the apps are getting the most 
# recent data and code.

source("00_get_the_CSV_things.R")

source("01_Bed_Unit_Utilization.R")

source("02_QPR_SPDATs.R")

source("02_QPR_EEs.R")

source("03_Veterans.R")

source("04_DataQuality.R")
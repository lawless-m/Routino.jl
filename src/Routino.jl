module Routino

export route, distance

const BINARY = "/usr/bin/routino-router"
const DATADIR = "/trip/osm"

function route(lat1::Real, lon1::Real, lat2::Real, lon2::Real; binary=BINARY, datadir=DATADIR, prefix="GB")
    split(String(read(`$binary --quickest --output-text --output-stdout --dir=$datadir --prefix=$prefix --lat1=$lat1 --lon1=$lon1 --lat2=$lat2 --lon2=$lon2`)), "\n")
end

function distance(lat1::Real, lon1::Real, lat2::Real, lon2::Real; binary=BINARY, datadir=DATADIR, prefix="GB")
    tline = filter(t->occursin("Waypt#2", t), route(lat1, lon1, lat2, lon2;  binary, datadir, prefix))
    if length(tline) == 1
        parts = split(tline[1], "\t")
        km = 1.2parse(Float64, split(strip(parts[5]), " ")[1])
        mins = 1.2parse(Float64, split(strip(parts[6]), " ")[1])
        (;km, mins)
    end
end
#==
lon1, lat1 = ( -1.7587022270945216,  53.67050050773988) # HD2
lon2, lat2 = ( -1.6091688317085435, 53.74083763716689) # pcode_centre(idx, "LS27 0AL")
route(lat1, lon1, lat2, lon2)
==#

###
end

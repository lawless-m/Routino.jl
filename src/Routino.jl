module Routino

export route, distance

const BINARY = "/usr/bin/routino-router"
const DATADIR = "/trip/osm"

const LoLa = typeof((lo=0.0, la=0.0))

function run(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB")
    try 
        read(`$binary --quiet --quickest --output-text --output-stdout --dir=$datadir --prefix=$prefix --lon1=$(wayp1.lo) --lat1=$(wayp1.la) --lon2=$(wayp2.lo) --lat2=$(wayp2.la)`)
    catch
        ""
    end
end

function route(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB")
    split(String(run(wayp1, wayp2;  binary, datadir, prefix)), "\n")
end

function distance(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB")
    tline = filter(t->occursin("Waypt#2", t), route(wayp1, wayp2;  binary, datadir, prefix))
    if length(tline) == 1
        parts = split(tline[1], "\t")
        km = 1.2parse(Float64, split(strip(parts[5]), " ")[1])
        mins = 1.2parse(Float64, split(strip(parts[6]), " ")[1])
        (;km, mins)
    end
end
#==
wayp1 = (lo=-1.7587022270945216, la=53.67050050773988) # HD2
wayp2 = (lo=-1.6091688317085435, la=53.74083763716689) # pcode_centre(idx, "LS27 0AL")
route(wayp1, wayp2)

wayp1 = (lo=-4.737703404818423, la=58.50695215591557)
wayp2 = (lo=-2.954101, la=53.479544)


==#

###
end

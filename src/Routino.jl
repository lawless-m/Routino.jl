module Routino

export route, distance, Connection, find_waypoint, add_waypoint!, calculate_route

const BINARY = "/home/matt/routino-3.3.3/src/router" 
#"/usr/bin/routino-router"

const DATADIR = "/trip/osm"

const LIB = "/home/matt/routino-3.3.3/src/libroutino.so" 
#"/usr/lib/libroutino.so.0"
const ROUTINO_API_VER = Cint(8)
const PROFILES = "/usr/share/routino/profiles.xml"
const TRANSLATIONS = "/usr/share/routino/translations.xml"

const LoLa = typeof((lo=0.0, la=0.0))

#==
 routino-router  --quickest --output-text --output-stdout --dir=/trip/osm --prefix=GB --lon1=-1.7587022270945216 --lat1=53.67050050773988 --lon2=-1.6091688317085435 --lat2=53.74083763716689 --profiles=/usr/share/routino/profiles.xml --translations=/usr/share/routino/translations.xml 
 ==#
function run(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB", profiles=PROFILES, translations=TRANSLATIONS)
    try 
        read(`$binary --quiet --quickest --output-text --output-stdout --dir=$datadir --prefix=$prefix --lon1=$(wayp1.lo) --lat1=$(wayp1.la) --lon2=$(wayp2.lo) --lat2=$(wayp2.la) --profiles=$profiles --translations=$translations`)
    catch
        ""
    end
end

function route(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB")
    split(String(run(wayp1, wayp2;  binary, datadir, prefix)), "\n")
end

function distance(wayp1::LoLa, wayp2::LoLa; binary=BINARY, datadir=DATADIR, prefix="GB", default=nothing)
    tline = filter(t->occursin("Waypt#2", t), route(wayp1, wayp2;  binary, datadir, prefix))
    if length(tline) == 1
        parts = split(tline[1], "\t")
        km = 1.2parse(Float64, split(strip(parts[5]), " ")[1])
        mins = 1.2parse(Float64, split(strip(parts[6]), " ")[1])
        (;km, mins)
    else
        default
    end
end
#==
wayp1 = (lo=-1.7587022270945216, la=53.67050050773988) # HD2
wayp2 = (lo=-1.6091688317085435, la=53.74083763716689) # pcode_centre(idx, "LS27 0AL")
route(wayp1, wayp2)

wayp1 = (lo=-4.737703404818423, la=58.50695215591557)
wayp2 = (lo=-2.954101, la=53.479544)
==#

struct Connection
    db::Ptr{Cvoid}
    profile::Ptr{Cvoid}
    translation::Ptr{Cvoid}
    waypoints::Vector{Ptr{Cvoid}}
    function Connection(profile="motorcar"; language="en", path=DATADIR, prefix="GB", profilexml=PROFILES, translationsxml=TRANSLATIONS)
        load_xml_profiles(profilexml)
        load_xml_translations(translationsxml)
        db = open_database(path, prefix)
        pf = get_profile(profile)
        validate_profile(db, pf)
        new(db, pf, get_translation(language), Ptr{Cvoid}[])
    end
end 

function uload_cstring(ptr)
    string = Vector{UInt8}()
    i = 1
    while (c = unsafe_load(ptr, i)) != 0
        push!(string, c)
        i += 1
    end
    String(string)
end
function uload_vstrings(list)
    strings = Vector{String}()
    i = 1
    while (stringp = unsafe_load(list,i)) != C_NULL
        push!(strings, uload_cstring(stringp))
        i += 1
    end
    strings
end


const DB = Ptr{Cvoid}
const Profile = Ptr{Cvoid}
const Waypoint = Ptr{Cvoid}
const Translation = Ptr{Cvoid}
const ProgressFunc= Ptr{Cvoid}

const ListString = Ptr{Ptr{UInt8}}

const OutputPtr = Ptr{Cvoid}

struct Output
    next::Ptr{Output}
    lon::Cfloat
    lat::Cfloat
    dist::Cfloat
    time::Cfloat
    speed::Cfloat
    type::Cint
    turn::Cint
    bearing::Cint
    name::Cstring
    desc1::Cstring
    desc2::Cstring
    desc3::Cstring
end

check_api_version(ver=ROUTINO_API_VER) = (@ccall LIB.Routino_Check_API_Version(ver::Cint)::Cint) == 0
open_database(path=DATADIR, prefix="GB") = @ccall LIB.Routino_LoadDatabase(path::Cstring, prefix::Cstring)::DB
load_xml_profiles(filename=PROFILES) = (@ccall LIB.Routino_ParseXMLProfiles(filename::Cstring)::Cint) == 0
load_xml_translations(filename=TRANSLATIONS) = (@ccall LIB.Routino_ParseXMLTranslations(filename::Cstring)::Cint) == 0
get_profile_names() = @ccall LIB.Routino_GetProfileNames()::ListString
get_profile(name::AbstractString) = @ccall LIB.Routino_GetProfile(name::Cstring)::Profile
validate_profile(db, profile) = (@ccall LIB.Routino_ValidateProfile(db::DB, profile::Profile)::Cint) == 0
get_translation(name="en") = @ccall LIB.Routino_GetTranslation(name::Cstring)::Translation
find_waypoint(lo, la, db, profile) = @ccall LIB.Routino_FindWaypoint(db::DB, profile::Profile, la::Cdouble, lo::Cdouble)::Waypoint
find_waypoint(lo, la, connection=Connection()) = find_waypoint(lo, la, connection.db, connection.profile)
calculate_route(waypoints::Vector{Waypoint}, options=Cint[1,9,512]; connection=Connection()) = calculate_route(waypoints, connection.db, connection.profile, connection.translation, options)

function calculate_route(waypoints::Vector{Ptr{Cvoid}}, db, profile, translation, options=Cint[1,9,512])
    @ccall LIB.Routino_CalculateRoute(db::DB, profile::Profile, translation::Translation, waypoints::Waypoint, length(waypoints)::Cint, reduce((a,i) -> a |= i, options, init=Cint(0))::Cint, C_NULL::Ptr{Cvoid})::Ptr{Output}
end

function calculate_route(connection, options=Cint[1,9,512])
    if length(connection.waypoints) > 1
        return calculate_route(connection.waypoints, connection.db, connection.profile, connection.translation, options)
    end
end

function add_waypoint!(lo::Float64, la::Float64, connection::Connection)
    wp = find_waypoint(lo, la, connection)
    if wp != C_NULL
        push!(connection.waypoints, wp)
        return true
    end
    false
end
#==
needed adding manually to the C code
print_profile(profile) = ccall((:Routino_PrintProfile, LIB), Cvoid, (Profile,), profile)
==#

function find()
    # using Routino
    connection = Connection("motorcar")
    add_waypoint!(-1.7587022270945216, 53.67050050773988, connection)
    add_waypoint!(-1.6091688317085435, 53.74083763716689, connection)
    calculate_route(connection)
end

###
end

module Routino

using CCallHelp

export route, distance, Router, find_waypoint, clear_waypoints, add_waypoint!, quickest_route, shortest_route, get_profile_names, close_router, free_xml, walk_to_distance

const BINARY = "/usr/bin/routino-router"
const DATADIR = "/trip/osm"
const LIB = "/usr/lib/libroutino.so.0"
const ROUTINO_API_VER = Cint(8)
const PROFILES = "/usr/share/routino/profiles.xml"
const TRANSLATIONS = "/usr/share/routino/translations.xml"


const DB = Ptr{Cvoid}
const Profile = Ptr{Cvoid}
const Waypoint = Ptr{Cvoid}
const Translation = Ptr{Cvoid}
const ProgressFunc= Ptr{Cvoid}

const PUchars = Ptr{Cuchar}
const ListString = Ptr{PUchars}

const LoLa = typeof((lo=0.0, la=0.0))
"""
    Router(profile="motorcar"; language="en", path=DATADIR, prefix="GB", profilexml=PROFILES, translationsxml=TRANSLATIONS)
Load the Routino Library and intialize it with its database and options.
This is the best way to use the library but was written after the shell out version
# Arguments
- `profile` - name of the profile to use, must be listed in the profilexml
- `language` - language to use, defaults to "en"
- `path` - directory containing the pem files generated by planetsplit - see the Routino docs
- `prefix` - Country prefix for the pem files defaults to "GB"
- `profilexml` - filename from which to load the profiles, defaults to "/usr/share/routino/profiles.xml"
- `translationsxml` filename from which to load the translations, defaults to "/usr/share/routino/translations.xml"
"""
struct Router
    db::Ptr{Cvoid}
    profile::Ptr{Cvoid}
    translation::Ptr{Cvoid}
    waypoints::Vector{Ptr{Cvoid}}
    function Router(profile="motorcar"; language="en", path=DATADIR, prefix="GB", profilexml=PROFILES, translationsxml=TRANSLATIONS)
        load_xml_profiles(profilexml)
        load_xml_translations(translationsxml)
        db = open_database(path, prefix)
        pf = get_profile(profile)
        validate_profile(db, pf)
        tr = get_translation(language)
        new(db, pf, tr, Ptr{Cvoid}[])
    end
end 

function close_router(r)
    @ccall LIB.Routino_UnloadDatabase(r.db::DB)::Cvoid
end

function free_xml()
     @ccall LIB.Routino_FreeXMLProfiles()::Cvoid
     @ccall LIB.Routino_FreeXMLTranslations()::Cvoid
end

"""
    clear_waypoints(r::Router)
Clear the waypoints in the active router, to reuse it for multiple route calculations
"""
function clear_waypoints(r::Router)
    foreach(free_ptr, r.waypoints)
    empty!(r.waypoints)
end

#==
 routino-router  --quickest --output-text --output-stdout --dir=/trip/osm --prefix=GB --lon1=-1.7587022270945216 --lat1=53.67050050773988 --lon2=-1.6091688317085435 --lat2=53.74083763716689 --profiles=/usr/share/routino/profiles.xml --translations=/usr/share/routino/translations.xml 
 ==#
function shell(wayp1::LoLa, wayp2::LoLa, binary=BINARY; datadir=DATADIR, prefix="GB", profiles=PROFILES, translations=TRANSLATIONS)
    try 
        read(`$binary --quiet --quickest --output-text --output-stdout --dir=$datadir --prefix=$prefix --lon1=$(wayp1.lo) --lat1=$(wayp1.la) --lon2=$(wayp2.lo) --lat2=$(wayp2.la) --profiles=$profiles --translations=$translations`)
    catch
        ""
    end
end
"""
    route(wayp1::LoLa, wayp2::LoLa, binary; datadir=DATADIR, prefix="GB")
Get the textual output from the shell invocation of the binary
"""
function route(wayp1::LoLa, wayp2::LoLa, binary; datadir=DATADIR, prefix="GB")
    split(String(shell(wayp1, wayp2, binary; datadir, prefix)), "\n")
end

"""
    distance(wayp1::LoLa, wayp2::LoLa, router=Router(), default=nothing)
    distance(wayp1::LoLa, wayp2::LoLa, binary, datadir=DATADIR, prefix="GB", default=nothing; options=1024) # 1025 for shortest
Calculate the route and return the `(km=0, mins=0)` or `default` using either the `Router` or the binary via the shell
"""
function distance(wayp1::LoLa, wayp2::LoLa, router::Router=Router(), default=nothing; options=1024) # quickest
    clear_waypoints(router)
    if add_waypoint!(wayp1, router) && add_waypoint!(wayp2, router)
        route = calculate_route(router, options)
        km_mins = walk_to_distance(route)
        delete_route(route)
        return km_mins === nothing ? default : km_mins
    end
    default
end

function distance(wayp1::LoLa, wayp2::LoLa, binary::AbstractString, datadir=DATADIR, prefix="GB", default=nothing)
    tline = filter(t->occursin("Waypt#2", t), route(wayp1, wayp2, binary; datadir, prefix))
    if length(tline) == 1
        parts = split(tline[1], "\t")
        km = parse(Float64, split(strip(parts[5]), " ")[1])
        mins = parse(Float64, split(strip(parts[6]), " ")[1])
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



struct COutput
    next::Ptr{COutput}
    lon::Cfloat
    lat::Cfloat
    dist::Cfloat
    time::Cfloat
    speed::Cfloat
    type::Cint
    turn::Cint
    bearing::Cint
    name::PUchars
    desc1::PUchars
    desc2::PUchars
    desc3::PUchars
end

check_api_version(ver=ROUTINO_API_VER) = (@ccall LIB.Routino_Check_API_Version(ver::Cint)::Cint) == 0
open_database(path=DATADIR, prefix="GB") = @ccall LIB.Routino_LoadDatabase(path::Cstring, prefix::Cstring)::DB
load_xml_profiles(filename=PROFILES) = (@ccall LIB.Routino_ParseXMLProfiles(filename::Cstring)::Cint) == 0
load_xml_translations(filename=TRANSLATIONS) = (@ccall LIB.Routino_ParseXMLTranslations(filename::Cstring)::Cint) == 0
"""
    get_profile_names()
Get the profile names currently loaded (via the xml)
"""
get_profile_names() = vec_string_from_ptr(@ccall LIB.Routino_GetProfileNames()::ListString)
get_profile(name::AbstractString) = @ccall LIB.Routino_GetProfile(name::Cstring)::Profile
validate_profile(db, profile) = (@ccall LIB.Routino_ValidateProfile(db::DB, profile::Profile)::Cint) == 0
get_translation(name="en") = @ccall LIB.Routino_GetTranslation(name::Cstring)::Translation
find_waypoint(lo, la, db, profile) = @ccall LIB.Routino_FindWaypoint(db::DB, profile::Profile, la::Cdouble, lo::Cdouble)::Waypoint
"""
    find_waypoint(wp, router=Router())
    find_waypoint(lo, la, router=Router())
Test if a waypoint is in the database.
# Arguments
- `wp` waypoint in (lo=0, la=0) format
- `la`, `lo`  Longitude, Latitude
"""
find_waypoint(wp::LoLa, router::Router=Router()) = find_waypoint(wp.lo, wp.la, router)
find_waypoint(lo::Float64, la::Float64, router::Router=Router()) = find_waypoint(lo, la, router.db, router.profile)

#calculate_route(waypoints::Vector{Waypoint}, options; router=Router()) = calculate_route(waypoints, router.db, router.profile, router.translation, options)
calculate_route(waypoints::Vector{Ptr{Cvoid}}, db, profile, translation, options) = @ccall LIB.Routino_CalculateRoute(db::DB, profile::Profile, translation::Translation, waypoints::Waypoint, length(waypoints)::Cint, options::Cint, C_NULL::Ptr{Cvoid})::Ptr{COutput}

function calculate_route(router, options)
    if length(router.waypoints) > 1
        return calculate_route(router.waypoints, router.db, router.profile, router.translation, options)
    end
end

"""
    quickest_route(router)::Ptr{COutput}
    shortest_route(router)::Ptr{COutput}
Run the calculation if there are sufficient waypoints returning either the quickest or shortest route.
"""
quickest_route(router) = calculate_route(router, 1024)
shortest_route(router) = calculate_route(router, 1025)

"""
    add_waypoint!(wp::LoLa, router::Router)::Bool
    add_waypoint!(lo::Float64, la::Float64, router::Router)::Bool
Add a waypoint to the router and return if it was found
# Arguments
- `wp` waypoint in `(lo=0, la=0)` format
- `lo`, `la` Longitude, Latitude
"""
add_waypoint!(wp::LoLa, router::Router) = add_waypoint!(wp.lo, wp.la, router)
function add_waypoint!(lo::Float64, la::Float64, router::Router)
    wp = find_waypoint(lo, la, router)
    if wp != C_NULL
        push!(router.waypoints, wp)
        return true
    end
    false
end

delete_route(ptr::Ptr{COutput}) = @ccall LIB.Routino_DeleteRoute(ptr::Ptr{COutput})::Cvoid

function walk_to_distance(ptr::Ptr{COutput})
    if ptr == C_NULL
        return
    end
    out = unsafe_load(ptr, 1)
    if out.next != C_NULL
        return walk_to_distance(out.next)    
    end
    

    (;km=round(Int, out.dist), mins=round(Int, out.time))
end

###
end

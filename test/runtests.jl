using Routino
using Test

@testset "Routino.jl" begin
    if isfile(Routino.BINARY)
        lon1, lat1 = ( -1.7587022270945216,  53.67050050773988) # HD2
        lon2, lat2 = ( -1.6091688317085435, 53.74083763716689) # pcode_centre(idx, "LS27 0AL")
        @test distance(lat1, lon1, lat2, lon2) == (km = 23.16, mins = 15.6)
    end
end

using Routino
using Test

@testset "Routino.jl" begin
    if isfile(Routino.BINARY)
        wayp1 = (lo=-1.7587022270945216, la=53.67050050773988) # HD2
        wayp2 = (lo=-1.6091688317085435, la=53.74083763716689) # pcode_centre(idx, "LS27 0AL")
        @test distance(wayp1, wayp2, Routino.BINARY) == (km = 19.3, mins = 13)
    end
    if isfile(Routino.LIB)
        connection = Connection("foot")
        add_waypoint!(-1.7587022270945216, 53.67050050773988, connection)
        add_waypoint!(-1.6091688317085435, 53.74083763716689, connection)
        out = calculate_route(connection)
        @test out != C_NULL
        @test typeof(out) == Ptr{Routino.COutput}
        @test distance(out) == (km = 15, mins = 229)
    end

end

using Routino
using Test

@testset "Routino.jl" begin
    if isfile(Routino.BINARY)
        wayp1 = (lo=-1.7587022270945216, la=53.67050050773988) # HD2
        wayp2 = (lo=-1.6091688317085435, la=53.74083763716689) # pcode_centre(idx, "LS27 0AL")
        @test distance(wayp1, wayp2) == (km = 23.16, mins = 15.6)
    end
end
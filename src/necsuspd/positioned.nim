import vmath, vec_tools, necsus, std/options, bumpy

type
    Positioned* = object
        ## A Position of a thing that can be rendered
        pos: IVec2
        lastPos: IVec2
        offset: IVec2
        precision: int32

    Follower* = object
        ## Tracks one object from another
        leader: EntityId
        offset: IVec2

proc positioned*(coords: IVec2, precision: int32 = 0): auto =
    Positioned(pos: coords, lastPos: coords, precision: precision)

proc positioned*(x, y: SomeInteger, precision: int32 = 0): auto =
    positioned(ivec2(x.int32, y.int32), precision)

proc toIVec2*(pos: Positioned | ptr Positioned): IVec2 =
    let joined = pos.pos + pos.offset
    result = ivec2(joined.x shr pos.precision, joined.y shr pos.precision)

proc toVec2*(pos: Positioned | ptr Positioned): Vec2 =
    let joined = pos.pos + pos.offset
    result = vec2(joined.x / (2 ^ pos.precision), joined.y / (2 ^ pos.precision))

proc x*(pos: Positioned | ptr Positioned): auto = pos.toIVec2.x

proc y*(pos: Positioned | ptr Positioned): auto = pos.toIVec2.y

template assign(name) =
    proc `name =`*(pos: ptr Positioned, value: int32) = pos.pos.`name` = value
    proc `name =`*(pos: ptr Positioned, value: int) = pos.pos.`name` = value.int32

assign(y)
assign(x)

proc pos*(pos: Positioned | ptr Positioned): IVec2 = pos.pos

proc `pos=`*(pos: ptr Positioned, newPos: IVec2) =
    pos.lastPos = pos.pos
    pos.pos = newPos

proc `offset=`*(pos: ptr Positioned, offset: IVec2) =
    pos.offset = offset

proc lastPos*(pos: Positioned): auto = pos.lastPos

proc angle*(pos: Positioned): float32 = (pos.lastPos - pos.pos).toVec2.angle.toDegrees * -1

proc follow*(leader: EntityId, offset: IVec2 = ivec2(0, 0)): Follower =
    ## Creates a follower
    Follower(leader: leader, offset: offset)

proc updateFollowers*(
    followers: FullQuery[(Follower, ptr Positioned)],
    getLeader: Lookup[(Positioned, )],
    delete: Delete
) =
    ## Updates the position of any entities following another entity
    for eid, (follower, pos) in followers:
        let leader = getLeader(follower.leader)
        if leader.isSome:
            pos.pos = leader.get[0].toIVec2 + follower.offset
        else:
            delete(eid)

proc segment*(pos: Positioned): auto = segment(pos.lastPos.toVec2, pos.toVec2)

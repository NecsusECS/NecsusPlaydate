import vmath, vec_tools, necsus, std/options, bumpy, fpvec

type
  Positioned* = object ## A Position of a thing that can be rendered
    pos, lastPos, offset: FPVec2

  Follower* = object ## Tracks one object from another
    leader: EntityId
    offset: FPVec2

proc positioned*(coords: FPVec2): auto =
  Positioned(pos: coords, lastPos: coords)

proc positioned*(coords: IVec2): auto =
  positioned(coords.toFPVec2)

proc positioned*(x, y: SomeInteger): auto =
  positioned(fpvec2(x.int32, y.int32))

proc toFPVec2*(pos: Positioned | ptr Positioned): FPVec2 =
  pos.pos + pos.offset

proc toIVec2*(pos: Positioned | ptr Positioned): IVec2 =
  pos.toFPVec2().toIVec2()

proc toVec2*(pos: Positioned | ptr Positioned): Vec2 =
  pos.toFPVec2().toVec2()

proc x*(pos: Positioned | ptr Positioned): auto =
  pos.x

proc y*(pos: Positioned | ptr Positioned): auto =
  pos.y

template assign(name) =
  proc `name=`*(pos: ptr Positioned, value: int32) =
    pos.pos.`name` = value.fp(FPVecPrecision)

  proc `name=`*(pos: ptr Positioned, value: int) =
    pos.pos.`name` = value.fp(FPVecPrecision)

assign(y)
assign(x)

proc pos*(pos: Positioned | ptr Positioned): IVec2 =
  pos.pos

proc `pos=`*(pos: ptr Positioned, newPos: IVec2 | FPVec2) =
  pos.lastPos = pos.pos
  pos.pos = newPos.toFPVec2

proc `offset=`*(pos: ptr Positioned, offset: IVec2 | FPVec2) =
  pos.offset = offset.toFPVec2

proc lastPos*(pos: Positioned): auto =
  pos.lastPos

proc angle*(pos: Positioned): FPInt32 =
  (pos.lastPos - pos.pos).angle.toDegrees * -1

proc follow*(leader: EntityId, offset: FPVec2 = fpvec2(0, 0)): Follower =
  ## Creates a follower
  Follower(leader: leader, offset: offset)

proc updateFollowers*(
    followers: FullQuery[(Follower, ptr Positioned)],
    getLeader: Lookup[(Positioned,)],
    delete: Delete,
) =
  ## Updates the position of any entities following another entity
  for eid, (follower, pos) in followers:
    let leader = getLeader(follower.leader)
    if leader.isSome:
      pos.pos = leader.get[0].toFPVec2 + follower.offset
    else:
      delete(eid)

proc segment*(pos: Positioned): auto =
  segment(pos.lastPos.toVec2, pos.toVec2)

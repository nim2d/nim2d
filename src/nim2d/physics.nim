## 2D rigid-body physics on Box2D.
##
## Build a `World` with some gravity, add static, dynamic or kinematic bodies,
## give them box or circle shapes, then call `update` each frame to step the
## simulation. Read a body's `position` and `angle` to draw it.
##
## Box2D is happiest in small units like meters, so pick a scale (say 50 pixels
## per unit), simulate in those units, and multiply when you draw, rather than
## feeding pixel-sized numbers to the solver.
##
## This needs Box2D installed (brew install box2d) and is imported on its own
## with `import nim2d/physics`, since not every program wants the dependency.

import std/math
import backend/box2d

type
  BodyType* = enum
    btStatic, btDynamic, btKinematic

  World* = ref object
    id: b2WorldId

  Body* = object
    id: b2BodyId

proc newWorld*(gravityX = 0.0, gravityY = 9.81): World =
  ## A physics world with the given gravity. Positive y points down, matching the
  ## screen, so the default pulls bodies downward.
  var def = b2DefaultWorldDef()
  def.gravity = b2Vec2(x: gravityX.cfloat, y: gravityY.cfloat)
  World(id: b2CreateWorld(addr def))

proc destroy*(w: World) =
  ## Free the world and everything in it.
  b2DestroyWorld(w.id)

proc update*(w: World, dt: float, subSteps = 4) =
  ## Advance the simulation by `dt` seconds. A steady `dt` and a few sub-steps
  ## give the most stable result.
  b2World_Step(w.id, dt.cfloat, subSteps.cint)

proc newBody*(w: World, x, y: float, kind = btDynamic): Body =
  ## Add a body at (x, y). Dynamic bodies move and collide, static ones never
  ## move (floors and walls), kinematic ones move only by the velocity you set.
  var def = b2DefaultBodyDef()
  def.`type` = case kind
    of btStatic: b2_staticBody
    of btDynamic: b2_dynamicBody
    of btKinematic: b2_kinematicBody
  def.position = b2Vec2(x: x.cfloat, y: y.cfloat)
  Body(id: b2CreateBody(w.id, addr def))

proc addBox*(b: Body, halfWidth, halfHeight: float,
             density = 1.0, friction = 0.6, restitution = 0.0) =
  ## Give the body a rectangular shape, sized by its half extents.
  var sd = b2DefaultShapeDef()
  sd.density = density.cfloat
  sd.material.friction = friction.cfloat
  sd.material.restitution = restitution.cfloat
  sd.enableContactEvents = true
  var poly = b2MakeBox(halfWidth.cfloat, halfHeight.cfloat)
  discard b2CreatePolygonShape(b.id, addr sd, addr poly)

proc addCircle*(b: Body, radius: float,
                density = 1.0, friction = 0.6, restitution = 0.0) =
  ## Give the body a circular shape.
  var sd = b2DefaultShapeDef()
  sd.density = density.cfloat
  sd.material.friction = friction.cfloat
  sd.material.restitution = restitution.cfloat
  sd.enableContactEvents = true
  var circle = b2Circle(center: b2Vec2(x: 0, y: 0), radius: radius.cfloat)
  discard b2CreateCircleShape(b.id, addr sd, addr circle)

proc position*(b: Body): tuple[x, y: float] =
  ## The body's center position.
  let p = b2Body_GetPosition(b.id)
  (p.x.float, p.y.float)

proc angle*(b: Body): float =
  ## The body's rotation in radians.
  b2Rot_GetAngle(b2Body_GetRotation(b.id)).float

proc velocity*(b: Body): tuple[x, y: float] =
  ## The body's linear velocity.
  let v = b2Body_GetLinearVelocity(b.id)
  (v.x.float, v.y.float)

proc setVelocity*(b: Body, x, y: float) =
  ## Set the body's linear velocity.
  b2Body_SetLinearVelocity(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))

proc applyForce*(b: Body, x, y: float) =
  ## Apply a steady force at the body's center.
  b2Body_ApplyForceToCenter(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), true)

proc applyImpulse*(b: Body, x, y: float) =
  ## Apply an instantaneous impulse at the body's center, for a kick or a jump.
  b2Body_ApplyLinearImpulseToCenter(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), true)

proc setPosition*(b: Body, x, y: float, angle = 0.0) =
  ## Teleport the body to a position and angle.
  b2Body_SetTransform(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), b2MakeRot(angle.cfloat))

proc destroy*(b: Body) =
  ## Remove the body from its world.
  b2DestroyBody(b.id)

proc `userData=`*(b: Body, value: int) =
  ## Tag a body with an integer of your own, handy for telling bodies apart in
  ## raycasts, queries and contact events.
  b2Body_SetUserData(b.id, cast[pointer](value))

proc userData*(b: Body): int =
  ## The integer set with `userData=`, or 0 if none was set.
  cast[int](b2Body_GetUserData(b.id))

# --- joints -----------------------------------------------------------------

type Joint* = object
  id: b2JointId

proc destroy*(j: Joint) =
  ## Remove a joint.
  b2DestroyJoint(j.id)

proc revoluteJoint*(w: World, a, b: Body, x, y: float,
                    enableMotor = false, motorSpeed = 0.0, maxMotorTorque = 0.0,
                    enableLimit = false, lowerAngle = 0.0, upperAngle = 0.0): Joint =
  ## A hinge pinning two bodies at the world point (x, y), with an optional motor
  ## and angle limits.
  var def = b2DefaultRevoluteJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.localAnchorA = b2Body_GetLocalPoint(a.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAnchorB = b2Body_GetLocalPoint(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.enableMotor = enableMotor
  def.motorSpeed = motorSpeed.cfloat
  def.maxMotorTorque = maxMotorTorque.cfloat
  def.enableLimit = enableLimit
  def.lowerAngle = lowerAngle.cfloat
  def.upperAngle = upperAngle.cfloat
  Joint(id: b2CreateRevoluteJoint(w.id, addr def))

proc distanceJoint*(w: World, a, b: Body, x1, y1, x2, y2: float,
                    enableSpring = false, hertz = 0.0, dampingRatio = 0.0): Joint =
  ## A rod or spring holding two world anchor points a fixed distance apart. With
  ## a spring it stretches; without one it stays rigid.
  var def = b2DefaultDistanceJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.localAnchorA = b2Body_GetLocalPoint(a.id, b2Vec2(x: x1.cfloat, y: y1.cfloat))
  def.localAnchorB = b2Body_GetLocalPoint(b.id, b2Vec2(x: x2.cfloat, y: y2.cfloat))
  def.length = hypot(x2 - x1, y2 - y1).cfloat
  def.enableSpring = enableSpring
  def.hertz = hertz.cfloat
  def.dampingRatio = dampingRatio.cfloat
  Joint(id: b2CreateDistanceJoint(w.id, addr def))

proc prismaticJoint*(w: World, a, b: Body, x, y, axisX, axisY: float,
                     enableMotor = false, motorSpeed = 0.0, maxMotorForce = 0.0,
                     enableLimit = false, lowerTranslation = 0.0, upperTranslation = 0.0): Joint =
  ## A slider letting two bodies move only along the axis (axisX, axisY), with an
  ## optional motor and travel limits.
  var def = b2DefaultPrismaticJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.localAnchorA = b2Body_GetLocalPoint(a.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAnchorB = b2Body_GetLocalPoint(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAxisA = b2Vec2(x: axisX.cfloat, y: axisY.cfloat)
  def.enableMotor = enableMotor
  def.motorSpeed = motorSpeed.cfloat
  def.maxMotorForce = maxMotorForce.cfloat
  def.enableLimit = enableLimit
  def.lowerTranslation = lowerTranslation.cfloat
  def.upperTranslation = upperTranslation.cfloat
  Joint(id: b2CreatePrismaticJoint(w.id, addr def))

proc weldJoint*(w: World, a, b: Body, x, y: float): Joint =
  ## Welds two bodies rigidly together at the world point (x, y).
  var def = b2DefaultWeldJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.localAnchorA = b2Body_GetLocalPoint(a.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAnchorB = b2Body_GetLocalPoint(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  Joint(id: b2CreateWeldJoint(w.id, addr def))

proc wheelJoint*(w: World, a, b: Body, x, y, axisX, axisY: float,
                 enableMotor = false, motorSpeed = 0.0, maxMotorTorque = 0.0): Joint =
  ## A wheel: a suspension spring along the axis plus a spinning motor, for cars.
  var def = b2DefaultWheelJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.localAnchorA = b2Body_GetLocalPoint(a.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAnchorB = b2Body_GetLocalPoint(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))
  def.localAxisA = b2Vec2(x: axisX.cfloat, y: axisY.cfloat)
  def.enableMotor = enableMotor
  def.motorSpeed = motorSpeed.cfloat
  def.maxMotorTorque = maxMotorTorque.cfloat
  Joint(id: b2CreateWheelJoint(w.id, addr def))

proc motorJoint*(w: World, a, b: Body, offsetX, offsetY, maxForce, maxTorque: float): Joint =
  ## Drives one body to a position and angle offset from another, like a top-down
  ## character controller pushed around without fighting the solver.
  var def = b2DefaultMotorJointDef()
  def.bodyIdA = a.id; def.bodyIdB = b.id
  def.linearOffset = b2Vec2(x: offsetX.cfloat, y: offsetY.cfloat)
  def.maxForce = maxForce.cfloat
  def.maxTorque = maxTorque.cfloat
  Joint(id: b2CreateMotorJoint(w.id, addr def))

proc angle*(j: Joint): float =
  ## The current angle of a revolute joint.
  b2RevoluteJoint_GetAngle(j.id).float

proc translation*(j: Joint): float =
  ## The current translation of a prismatic joint.
  b2PrismaticJoint_GetTranslation(j.id).float

proc setMotorSpeed*(j: Joint, speed: float) =
  ## Drive a revolute joint's motor at `speed`. Enable the motor when you create
  ## the joint with `enableMotor = true`.
  b2RevoluteJoint_SetMotorSpeed(j.id, speed.cfloat)

# --- raycasts and queries ---------------------------------------------------

type RayHit* = object
  hit*: bool                  ## whether the ray struck anything
  body*: Body                 ## the body it struck (only when `hit`)
  x*, y*: float               ## the point of impact
  nx*, ny*: float             ## the surface normal there
  fraction*: float            ## how far along the ray, 0 at the start, 1 at the end

proc raycast*(w: World, x1, y1, x2, y2: float): RayHit =
  ## Cast a ray from (x1, y1) to (x2, y2) and return the closest body it hits.
  let r = b2World_CastRayClosest(w.id, b2Vec2(x: x1.cfloat, y: y1.cfloat),
    b2Vec2(x: (x2 - x1).cfloat, y: (y2 - y1).cfloat), b2DefaultQueryFilter())
  if r.hit:
    RayHit(hit: true, body: Body(id: b2Shape_GetBody(r.shapeId)),
           x: r.point.x.float, y: r.point.y.float,
           nx: r.normal.x.float, ny: r.normal.y.float, fraction: r.fraction.float)
  else:
    RayHit(hit: false)

proc collectShape(shapeId: b2ShapeId, ctx: pointer): bool {.cdecl.} =
  cast[ptr seq[Body]](ctx)[].add Body(id: b2Shape_GetBody(shapeId))
  true

proc queryBox*(w: World, x, y, width, height: float): seq[Body] =
  ## Every body whose shapes overlap the box (x, y, width, height).
  result = @[]
  let aabb = b2AABB(lowerBound: b2Vec2(x: x.cfloat, y: y.cfloat),
                    upperBound: b2Vec2(x: (x + width).cfloat, y: (y + height).cfloat))
  discard b2World_OverlapAABB(w.id, aabb, b2DefaultQueryFilter(), collectShape, addr result)

# --- contact events ---------------------------------------------------------

type Contact* = object
  a*, b*: Body

proc beginContacts*(w: World): seq[Contact] =
  ## Pairs of bodies that started touching during the last `update`. Compare their
  ## `userData` to tell which is which.
  result = @[]
  let ev = b2World_GetContactEvents(w.id)
  if ev.beginEvents != nil:
    let arr = cast[ptr UncheckedArray[b2ContactBeginTouchEvent]](ev.beginEvents)
    for i in 0 ..< ev.beginCount.int:
      result.add Contact(a: Body(id: b2Shape_GetBody(arr[i].shapeIdA)),
                         b: Body(id: b2Shape_GetBody(arr[i].shapeIdB)))

proc endContacts*(w: World): seq[Contact] =
  ## Pairs of bodies that stopped touching during the last `update`.
  result = @[]
  let ev = b2World_GetContactEvents(w.id)
  if ev.endEvents != nil:
    let arr = cast[ptr UncheckedArray[b2ContactEndTouchEvent]](ev.endEvents)
    for i in 0 ..< ev.endCount.int:
      result.add Contact(a: Body(id: b2Shape_GetBody(arr[i].shapeIdA)),
                         b: Body(id: b2Shape_GetBody(arr[i].shapeIdB)))

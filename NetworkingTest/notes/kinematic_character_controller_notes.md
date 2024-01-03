# Custom move and slide

### Possible improvement: account for multiple collision results per move
There are some reconciliation errors that happen because collision order is just slightly off compared to the original. More specifically, let's say during one slide iteration, there are two surfaces we could hit. Since we only report the deepest collision as a result of our call to `move_and_collide`, we could get one or the other, and then slide along only that. 

Why would this be inconsistent?

Take the example of a character moving from a flat surface up to a ramp. For the sake of argument, assume the character velocity is actually pointed directly against the ramp normal (as opposed to flush with floor). Therefore, if our collision says we hit the ramp first, velocity will be cancelled to 0, and we stop moving altogether. However, if we hit the floor first, velocity will be slid so that it's flush to the floor, and will then be able to slide up the ramp.
```
\      
 \ 
  \_<-()_____
```

- Via experimentation, it seems that the collision detection does know about the two surfaces in any case (if we ask `move_and_collide` to return all collisions instead of just the deepest). Wondering if this can be used to make the interaction more consistent
- On second thought, this isn't true...it's possible collision detection doesn't find both surfaces.

- Alternatively, we could fundamentally rework the movement algo into a "target point" algorithm, such that instead of taking in a velocity and sliding it along surfaces, we would take in some point we want to move towards, and have the algorithm try to slide towards that point. 
- Whereas the current system is sort of "fire and forget," and is thus vulnerable to inconsistencies because there is no path correction / overarching goal, a target point system should ideally be more consistent because we always try to converge to a single position. Idea is kind of stolen from Andrea Catania
- In the above example, we might set a target point as being somewhere in the ground below the crease between floor and ramp. Then if we hit the floor first, we slide along it but won't slide up ramp since that moves us away from target. If we hit the ramp first, we'll then move down towards floor to get closer to point, but not slide along floor. Ends up in same position

### Inconsistencies due to floor snap
Noticed errors when going from flat floor up onto the edge of a ramp (approaching ramp from side).
Actual collision / move and slide behavior seemed consistent between erroneous and non-erroneous replay runs.
What was different was ground detection being different due to tiny inconsistencies in move_and_slide position (which are expected)
This in turn led to the floor snapping being wildly different. If we detected flat floor, we'd move straight down. But if we detected ramp edge floor, we'd be pulled sideways
This occurs even if we aren't colliding with floor, since ground check has a wide margin (almost 1/5 character height!)

One idea for a fix was to snap towards some combination of the two floors, as if there were a floor between the ground and ramp, at a middle angle
But this wouldn't work, since the floor detection logic does not detect both floors at once, consistently (and we don't expect it should be able to)

Via random experimentation, I found that changing the snap direction from `-1 * floor_normal` to `position_implied_by_floor_contact - current_position` fixed this issue
When I first implemented the snap, I assumed that `-1 * floor_normal` would always be the direction towards the floor contact we discovered, but this isn't true
Reason is the "wall floor" part of floor detection logic, where if we hit a wall, we check for a floor at the base of that wall. 
The direction downwards along the wall (aka direction towards the contact point) is not always the same as the floor contact normal
I'm still not sure why this reduces the inconsistency...it stands to reason to me that the fundamental problem of "minor diff in start position -> could find a completely different floor" is still an issue

Possible this is because in prior behavior, we'd snap straight down into a "wall floor", which causes us to clip geometry -> inconsistent collision resolution
Still think it's possible to have snap inconsistencies even after this fix, but very rare in practice
If it becomes an issue, one avenue is to snap to the wall collision point instead of the wall floor collision. This helps because we'll end up in close to the same position regardless of if we detect the ramp edge as wall vs floor

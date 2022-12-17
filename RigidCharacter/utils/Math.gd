extends Object
class_name Math

static func project_onto_plane_along_axis(vector:Vector3, normal:Vector3, 
axis:int) -> Vector3:
    """
        Modifying only the specified axis, projects the vector onto the plane
        defined by the normal
            n = (nx, ny, nz)
        
        We assume the plane starts at the origin. This example projects along
        the y axis. We begin with vector v 
            v = (vx, vy, vz)
        Our projection is
            p = (vx, py, vz)
        We know p must lie on the plane, so it is orthogonal to n 
            dot(p, n) = 0, aka (vx * nx) + (py * ny) + (vz * nz) = 0 
        We solve the unknown 
            py = -(vx * nx + vz * nz) / ny
    """
    var projected = vector
    
    match axis:
        0:
            projected.x = 0
            projected.x = -projected.dot(normal) / normal.x if normal.x else NAN
        2:
            projected.z = 0
            projected.z = -projected.dot(normal) / normal.z if normal.z else NAN
        _:
            projected.y = 0
            projected.y = -projected.dot(normal) / normal.y if normal.y else NAN
    
    return projected

static func get_slope_velocity(velocity:Vector3, normal:Vector3) -> Vector3:
    """
    preserves horizontal component of velocity when moving on a slope
    """
    return project_onto_plane_along_axis(velocity, normal, 1)

static func deg_to_deg360(deg : float):
    deg = fmod(deg, 360.0)
    if deg < 0.0:
        deg += 360.0
    return deg

static func shortest_deg_between(deg1 : float, deg2 : float):
    return min(
        abs(deg1 - deg2),
        min(abs((deg1 - 360.0) - deg2), abs((deg2 - 360.0) - deg1)))

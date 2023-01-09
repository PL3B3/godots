extends Reference

static func intersect_ray_sphere(ray_start:Vector3, ray_end:Vector3, 
sphere_pos:Vector3, sphere_radius:float, write_to_array:Array):
	"""
		
	"""
	
	var ray = ray_end - ray_start
	var range_sqr = ray.length_squared()
	
	var sphere_offset = sphere_pos - ray_start
	var sphere_range_sqr = sphere_offset.length_squared()
	
	var angle_diff = (ray).angle_to(sphere_offset)
	
	write_to_array

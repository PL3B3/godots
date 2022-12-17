extends Object

"""
{
	poolbytearrays are passed by value, unless they're passed as part of an array, so if we get a poolarray as element 3 of an array a, then call a[3].resize(),  and then set some variable v = a[3], then v won't be equal to a resized a[3]. instead, we must set v = p first, then resize
	
	dict indexing by number is faster
}

{
	
}
"""

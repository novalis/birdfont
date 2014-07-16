/*
    Copyright (C) 2014 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/

using Cairo;
using Math;

namespace BirdFont {

/** A class for converting control points. */
public class PointConverter {

	Path original_path;
	Path quadratic_path;
	int points_on_segment = 0;

	public PointConverter (Path path) {	
		original_path = path;
	}

	public Path get_quadratic_path () {
		Path p;
		EditPoint prev;
		double x, y;
		
		quadratic_path = original_path.copy ();
		p = get_estimated_cubic_path ();
		p.remove_points_on_points ();

		if (p.points.size < 2) {
			return new Path ();
		}


		foreach (EditPoint e in p.points) {
			PenTool.convert_point_type (e, PointType.DOUBLE_CURVE);
		}
	
		p.add_hidden_double_points ();

		p.create_list ();
		prev = p.get_last_point ();
		foreach (EditPoint ep in p.points) {
			if (ep.type == PointType.QUADRATIC) {
				x = prev.get_right_handle ().x;
				y = prev.get_right_handle ().y;
				ep.get_left_handle ().move_to_coordinate (x, y);
			}
			prev = ep;
		}
						
		return p;
	}

	public Path get_estimated_cubic_path () {
		EditPoint start;
		EditPoint stop;
		EditPoint new_start;
		EditPoint e;
		double step, distance, px, py;
		
		if (quadratic_path.points.size <= 1) {
			return quadratic_path;
		}

		start = quadratic_path.get_first_point ();
		stop = start.get_next ();

		if (points_on_segment > 5) {
			warning ("Too many point on segment.");
			return quadratic_path;
		}

		for (int i = 0; i < quadratic_path.points.size; i++) {
			
			if (start.get_right_handle ().type == PointType.CUBIC || stop.get_left_handle ().type == PointType.CUBIC) {
				find_largest_distance (start, stop, start.copy (), stop.copy (), out distance, out px, out py);
				
				if (distance > 0.11) { // range 0.1 - 0.3, default 0.11
					e = new EditPoint ();
					quadratic_path.get_closest_point_on_path (e, px, py);
					e.type = PointType.CUBIC;
					e.get_left_handle ().type = PointType.CUBIC;
					e.get_right_handle ().type = PointType.CUBIC;
					quadratic_path.insert_new_point_on_path (e);
					
					quadratic_path.create_list ();
					points_on_segment++;													
					return get_estimated_cubic_path ();
				}
			}
			points_on_segment = 0;
			
			if (i == quadratic_path.points.size - 2) {
				start = stop;
				stop = quadratic_path.get_first_point ();
			} else {
				new_start = stop;
				stop = new_start.get_next ();
				start = new_start;
			}
		}
				
		return quadratic_path;
	}

	// TODO: Optimize
	public static void find_largest_distance (EditPoint a0, EditPoint a1, EditPoint b0, EditPoint b1, out double distance, out double px, out double py) {
		double max_d;
		double min_d;
		int steps = (int) (1.6 * Path.get_length_from (a0, a1));
		double x, y;
		double x_out, y_out;
		
		PenTool.convert_point_segment_type (b0, b1, PointType.DOUBLE_CURVE);
		
		x = 0;
		y = 0;
		x_out = 0;
		y_out = 0;

		steps = 20; // FIXME: adjust to length
		
		max_d = double.MIN;
		min_d = double.MAX;
		Path.all_of (a0, a1, (xa, ya, ta) => {
			
			min_d = double.MAX;
			Path.all_of (b0, b1, (xb, yb, tb) => {
				double d = Path.distance (xa, xb, ya, yb);
				
				if (d < min_d) {
					min_d = d;
					x = xa;
					y = ya;					
				}
				
				return true;
			}, steps);
					
			if (min_d > max_d) {
				max_d = min_d;
				x_out = x;
				y_out = y;
			}
			
			return true;
		}, steps);

		distance = max_d;
		px = x_out;
		py = y_out;
	}
}

}

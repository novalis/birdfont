/*
    Copyright (C) 2012 2013 2014 2015 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/
using Math;

namespace BirdFont {

public class GsubTable : OtfTable {
	
	GlyfTable glyf_table;
	
	public GsubTable (GlyfTable glyf_table) {
		this.glyf_table = glyf_table;
		id = "GSUB";
	}
	
	public override void parse (FontData dis) throws GLib.Error {
	}

	public void process () throws GLib.Error {
		FontData fd;
		FontData clig_subtable;
		uint16 length;
		
		LigatureSetList clig;
		ContextualLigatureSet contextual;

		uint16 feature_lookups;
		uint16 lookups_end;
		
		Gee.ArrayList<FontData> chain_data;
		
		fd = new FontData ();
		clig = new LigatureSetList.clig (glyf_table);
		contextual = new ContextualLigatureSet (glyf_table);
		
		fd.add_ulong (0x00010000); // table version
		fd.add_ushort (10); // offset to script list
		fd.add_ushort (30); // offset to feature list
		fd.add_ushort (contextual.has_ligatures () ? 46 : 44); // offset to lookup list
		
		// script list
		fd.add_ushort (1);   // number of items in script list
		fd.add_tag ("DFLT"); // default script
		fd.add_ushort (8); // offset to script table from script list
		
		// script table
		fd.add_ushort (4); // offset to default language system
		fd.add_ushort (0); // number of languages
		
		// LangSys table 
		fd.add_ushort (0); // reserved
		fd.add_ushort (0); // required features (0xFFFF is none)
		fd.add_ushort (1); // number of features
		fd.add_ushort (0); // feature index
		
		// feature table
		fd.add_ushort (1); // number of features
		
		fd.add_tag ("clig"); // feature tag
		fd.add_ushort (8); // offset to feature
		// FIXME: Should it be liga and clig?

		clig = new LigatureSetList.clig (glyf_table);
		contextual = new ContextualLigatureSet (glyf_table);

		feature_lookups = contextual.has_ligatures () ? 2 : 1;
		
		fd.add_ushort (0); // feature prameters (null)
		fd.add_ushort (feature_lookups); // number of lookups
		
		if (contextual.has_ligatures ()) {
			fd.add_ushort (1 + contextual.get_size ()); // lookup chained_context (etc.) The chained context tables are listed here but the actual ligature table is only referenced in the context table
			fd.add_ushort (0); // lookup clig_subtable
		} else {
			fd.add_ushort (0); // lookup clig_subtable
		}
		
		clig_subtable = clig.get_data (glyf_table);
		chain_data = get_chaining_contextual_substition_subtable (contextual);
		
		// lookup table
		uint16 lookups;
		
		if (contextual.has_ligatures ()) {
			lookups = 2 + (uint16) contextual.get_size ();
		} else {
			lookups = 1;
		}
		
		fd.add_ushort (lookups); // number of lookups
		
		if (contextual.has_ligatures ()) {
			uint16 offset_to_lookup;

			offset_to_lookup = 6 + 2 * contextual.get_size ();
			fd.add_ushort (offset_to_lookup); // offset to lookup 1, regular ligatures
			
			for (int i = 0; i < contextual.get_size (); i++) {
				offset_to_lookup += 8;
				// offset to ligature lookups used in chaining substitution
				fd.add_ushort (offset_to_lookup);
			}

			// offset to lookup for the chain table
			offset_to_lookup += 8;
			fd.add_ushort (offset_to_lookup); 
		} else {
			fd.add_ushort (4); // offset to lookup 1 
		}
		
		lookups_end = 8; // regular ligatures
		
		if (contextual.has_ligatures ()) {
			lookups_end += 8 * contextual.get_size (); // contextual ligatures
			lookups_end += 6; // chaining table
			lookups_end += 2 * (uint16) contextual.get_size (); // chaining subtables
		}
		
		length = 0;
		fd.add_ushort (4); // lookup type 
		fd.add_ushort (0); // lookup flags
		fd.add_ushort (1); // number of subtables
		fd.add_ushort (lookups_end + length); // array of offsets to subtable 
		length += (uint16) clig_subtable.length_with_padding ();
		lookups_end -= 8;
		
		if (contextual.has_ligatures ()) {			
			
			for (int i = 0; i < contextual.ligatures.size; i++) {
				fd.add_ushort (4); // lookup type 
				fd.add_ushort (0); // lookup flags
				fd.add_ushort (1); // number of subtables

				LigatureSetList ligature_set = contextual.ligatures.get (i);
				fd.add_ushort (lookups_end + length); // array of offsets to subtable
				length += (uint16) ligature_set.get_data (glyf_table).length_with_padding ();
				
				lookups_end -= 8;
			}

			fd.add_ushort (6); // lookup type 
			fd.add_ushort (0); // lookup flags
			fd.add_ushort (contextual.get_size ()); // number of subtables
			
			foreach (FontData d in chain_data) {
				fd.add_ushort (lookups_end + length); // array of offsets to subtable
				length += (uint16) d.length_with_padding ();
			}
			
			lookups_end -= 6 + 2 * chain_data.size;
		}
		
		if (lookups_end != 0) {
			warning (@"Wrong offset to end of lookups, $lookups_end bytes left.");
		}
		
		fd.append (clig_subtable);
		
		if (contextual.has_ligatures ()) {
			foreach (LigatureSetList s in contextual.ligatures) {
				fd.append (s.get_data (glyf_table));
			}

			foreach (FontData d in chain_data) {
				fd.append (d);
			}
		}
		
		fd.pad ();
		
		this.font_data = fd;
	}

	// chaining contextual substitution format3
	Gee.ArrayList<FontData> get_chaining_contextual_substition_subtable (ContextualLigatureSet contexts) throws GLib.Error {
		Gee.ArrayList<FontData> fd = new Gee.ArrayList<FontData> ();
		uint16 ligature_lookup_index = 1;
		
		foreach (ContextualLigature context in contexts.ligature_context) {
			fd.add (context.get_data (glyf_table, ligature_lookup_index)); 
			ligature_lookup_index++;
		}
		
		return fd;
	}
	
	void parse_ligatures (FontData fd, int table_start) {
		fd.seek (table_start);
		
		uint16 identifier = fd.read_ushort ();
		
		if (identifier != 1) {
			warning (@"Bad identifier expecting 1 found $identifier");
		}
		
		uint16 coverage_offset = fd.read_ushort (); // TODO: read coverage
		uint16 num_sets = fd.read_ushort ();
		
		Gee.ArrayList<int> liga_set_offsets = new Gee.ArrayList<int> ();
		for (int i = 0; i < num_sets; i++) {
			uint16 liga_set_offset = fd.read_ushort ();
			liga_set_offsets.add (table_start + liga_set_offset);
		}
		
		foreach (int liga_set_pos in liga_set_offsets) {
			fd.seek (liga_set_pos);
			parse_ligature_set (fd);
		}		
	}
	
	/** Parse ligature set at the current position. */
	void parse_ligature_set (FontData fd) {
		int liga_start = fd.get_read_pos ();
		uint nliga = fd.read_ushort ();
		Gee.ArrayList<int> offsets = new Gee.ArrayList<int> ();
		
		for (uint i = 0; i < nliga; i++) {
			int off = fd.read_ushort ();
			offsets.add (off);
		}

		foreach (int off in offsets) {
			fd.seek (liga_start);
			fd.seek_relative (off);
			uint16 lig = fd.read_ushort ();
			uint16 nlig_comp = fd.read_ushort ();
			
			for (int i = 1; i < nlig_comp; i++) {
				uint16 lig_comp = fd.read_ushort ();
			} 
		}
	}

	/** 
	 * @param glyphs Name of glyphs or unicode values separated by space.
	 * @return glyph names
	 */
	public static Gee.ArrayList<string> get_names (string glyphs) {
		Gee.ArrayList<string> names = new Gee.ArrayList<string> ();
		Font font = BirdFont.get_current_font ();
		string[] parts = glyphs.strip ().split (" ");
								
		foreach (string p in parts) {		
			if (p.has_prefix ("U+") || p.has_prefix ("u+")) {
				p = (!) Font.to_unichar (p).to_string ();
			}
			
			if (!font.has_glyph (p)) {
				warning (@"The character $p does have a glyph.");
				p = ".notdef";
			}
			
			if (p != "") {
				names.add (p);
			}
		}
		
		return names;
	}
}

}

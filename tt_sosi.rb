#-----------------------------------------------------------------------------
# Version: 1.0.0
# Compatible: SketchUp 6.0 (PC)
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------

module TT_SOSI
	
	unless file_loaded?('tt_sosi.rb')
	# Menus
	plugins_menu = UI.menu('Plugins')
	plugins_menu.add_item('Add SOSI names')		{ self.add_sosi_names }
	end
	
	
	def self.add_sosi_names
		model = Sketchup.active_model
		
    filename = Sketchup.read_default('TT_SOSI', 'path')
    
    unless filename && File.exist?( filename )
      filename = UI.openpanel('Open CSV File', nil, '*.csv')
      return if filename.nil?
      Sketchup.write_default('TT_SOSI', 'path', File.expand_path(filename) )
      puts filename
    end
		
		layers = {}
		
		file = File.open(filename, 'r')
		data = file.read
		file.close
		
		# Load layer descriptions
		data.each_line { |line|
			next if line.match(/([1-9]\d\d\d);.*;.*/).nil?
			code, description, theme = line.split(';')
			
			if layers.key?(code)
				layers[code][0].insert(description)
				layers[code][1].insert(theme[0,1])
			else
				d = Set.new
				d.insert(description)
				t = Set.new
				t.insert(theme[0,1])
				layers[code] = [d, t]
			end
		}
		
		self.start_operation('Add SOSI names')
		
		# Rename model layers
		model.layers.each { |layer|
			match = layer.name.match(/[1-9]\d\d\d/)
			next if match.nil?
			code = match[0]
			descriptions, themes = layers[code]
			layer.name = "#{code} - #{descriptions.to_a.join(', ')} (#{themes.to_a.join})"
		}
		
		model.commit_operation
		UI.refresh_inspectors
	end
	
	
	def self.start_operation(name)
		model = Sketchup.active_model
		if Sketchup.version.split('.')[0].to_i >= 7
			model.start_operation(name, true)
		else
			model.start_operation(name)
		end
	end
	
end # module

#-----------------------------------------------------------------------------
file_loaded('tt_sosi.rb')
#-----------------------------------------------------------------------------
require 'sketchup.rb'

module TT_SOSI

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins')
    menu.add_item('Import SOSI') { self.import_dialog }
    file_loaded(__FILE__)
  end


  def self.import_dialog
    filename = UI.openpanel("Open SOSI File", nil, "SOSI|*.sos||")
    self.import_file(filename) if filename
    nil
  end


  def self.import_file(filename)
    Sketchup.status_text = 'Reading file...'
    parser = SosiParser.new(filename)

    Sketchup.status_text = 'Parsing file...'
    parser.read

    puts "Points: #{parser.points.size}"
    puts "Curves: #{parser.curves.size}"
    #p parser.curves
    #return

    Sketchup.status_text = 'Generating geometry...'
    start_time = Time.now.to_i
    model = Sketchup.active_model
    begin
      model.start_operation('Import SOSI', true)
      group = model.active_entities.add_group
      entities = group.entities
      parser.points.each { |point|
        entities.add_cpoint(point)
      }
      parser.curves.each { |curve|
        if curve.size > 1
          entities.add_curve(curve)
        else
          puts "> Curve with #{curve.size} point"
          entities.add_cpoint(curve.first)
        end
      }
    ensure
      model.commit_operation
      puts "> Total Time: #{Time.now.to_i - start_time}"
      Sketchup.status_text = ''
    end
  end


  # References:
  # * del1_2_realiseringsosigml-4.0.pdf
  # * https://snl.no/EUREF89
  # * http://www.kartverket.no/kunnskap/kart-og-kartlegging/Referanseramme/Referanserammer-for-Norge/
  # * http://www.skogoglandskap.no/brukerstotte/1171626813.98/maphelp_view
  # * http://www.dmap.co.uk/utmworld.htm
  # * http://www.milvang.no/gps/datum/datum.html
  # * http://www.latlong.net/place/trondheim-norway-2940.html
  # * http://www.kartverket.no/globalassets/posisjonstjenester/euref89ntmbeskrivelse.pdf
  # * http://data.kartverket.no/download/content/geodataprodukter?korttype=3598&aktualitet=All&datastruktur=All&dataskema=All&page=1&amp%3Baktualitet=All&amp%3Bdatastruktur=All&amp%3Bdataskema=All
  #
  # UTM/EUREF89 (Universal Transvers Mercator) er et internasjonalt (europeisk)
  # koordinatsystem som fra 1994 er vedtatt å være Norges offisielle
  # koordinatsystem (som er vanlig brukt i GPS-mottakere).
  #
  # WGS84 (World Geodetic System 1984) er internasjonalt (globalt)
  # koordinatsystem.
  #
  # UTM/EUREF89 finnes i flere ulike soner tilpasset forskjellige deler av
  # landet. For kart som dekker hele Norge benyttes vanligvis UTM/EUREF89 sone
  # 33. WGS84 har ingen soner.
  #
  # UTM/EUREF89
  # Dette er et internasjonalt (europeisk) koordinatsystem, og siden 1994 Norges
  # offisielle koordinatsystem for alle kart (på Norges hovedland). UTM var
  # tidligere mest brukt for kart i små målestokker
  # (målestokk 1:50000 og mindre), men er nå tatt i bruk for de aller fleste
  # formål.
  # 
  # Norge berører UTM sonene 31-36, men det er anbefalt å bruke UTM sone 32 for
  # hele Sør-Norge til Nord-Trøndelag, 33 for Nordland og Troms, og 35 for
  # Finnmark.
  # Soneaksenes origo er på 0 o bredde. Koordinatene angis i meter fra sonens
  # origo, og punktet i Vadsø vil for eksempel ha koordinater
  # Nord=7776893.33, Øst=604333.87 i sone 35 (ofte kalt UTM35). Vadsø ligger
  # altså ca 7770 km nord for ekvator.
  # EUREF89 er for alle praktiske formål identisk med WGS84 som er betegnelsen
  # på et mye brukt globalt system.
  #
  # WGS84
  # WGS84 er så og si identisk med EUREF89. WGS84 brukes primært til å beskrive
  # plassering globalt på jordkloden. Derfor oppgis koordinatene i desimalgrader
  # i lengde (Øst) og bredde (Nord). Desimalgrader kan omregnes til antall
  # grader minutter og sekunder nord for ekvator og øst for 0-meridianen
  # (greenwich) .
  class SosiParser

    STATE_FIND_COORDS = 0
    STATE_FIND_TYPE   = 1
    STATE_READ_POINT  = 2
    STATE_READ_CURVE  = 3

    attr_reader :points, :curves

    def initialize(filename)
      @filename = filename
      @state = STATE_FIND_COORDS
      @zone = nil
      @coords = []
      @points = []
      @curves = []
    end

    def read
      data = read_data(@filename)
      parse_data(data)
      nil
    end

    private

    def read_data(filename)
      # TODO: Read header line by line. Sniff out TEGNSETT. Reopen in encoding.
      encoding = Encoding.find('ISO8859-10')
      File.read(filename, :encoding => encoding)
    end

    def parse_data(data)
      i = 0

      # TODO: Read from file.
      @zone = koordsys_code_to_utm_zone(23) # KOORDSYS
      @scale = 0.01 # ENHET

      state = STATE_FIND_COORDS
      data.each_line { |line|
        #puts line
        case state
        when STATE_FIND_COORDS
          state = find_coords(line)
        when STATE_FIND_TYPE
        when STATE_READ_POINT
        when STATE_READ_CURVE
        end
        
        i += 1
        #raise 'max read' if i > 50
        #return 'max read' if i > 50
      }
    end

    REGEX_COORDS = /^(\d+) (\d+)$/
    def find_coords(line)
      #puts "  > find_coords"
      result = REGEX_COORDS.match(line)
      if result
        north = result[1].to_i
        east = result[2].to_i
        utm = koordsys_to_utm(north, east)
        #puts utm.to_latlong
        point = Sketchup.active_model.utm_to_point(utm)
        @coords << point
      else
        if line.start_with?('.PUNKT ')
          #puts "    > point"
          @points.concat(@coords)
          @coords.clear
        elsif line.start_with?('.KURVE ')
          #puts "    > curve (#{@coords.size})"
          @curves << @coords.dup
          @coords.clear
        end
      end
      STATE_FIND_COORDS
    end

    UTMZone = Struct.new(:number, :letter)

    def koordsys_to_utm(north, east)
      x = north * @scale
      y = east * @scale
      #Geom::UTM.new(@zone.number, @zone.letter, y, x)
      Geom::UTM.new(@zone.number, @zone.letter, x, y)
    end

    def koordsys_code_to_utm_zone(code)
      case code
      when 23
        # UTM sone 33 basert på EUREF89/WGS84
        UTMZone.new(33, 'W')
      else
        raise NotImplementedError, "KOORDSYS #{code}"
      end
    end

  end # class

end # module
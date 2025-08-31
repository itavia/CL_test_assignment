# frozen_string_literal: true

class RoutesQuery
  def self.call(flight_params)
    new(flight_params).send(:build)
  end

  def initialize(flight_params)
    @carrier          = flight_params[:carrier]
    @departure_from   = flight_params[:departure_from]
    @departure_to     = flight_params[:departure_to]
    @route            = flight_params[:route]
    @min_connection   = Flights::Config::MIN_CONNECTION_TIME
    @max_connection   = Flights::Config::MAX_CONNECTION_TIME
  end

  private

  def build
    legs = @route.each_cons(2).to_a

    queries = []

    legs.each_with_index do |(origin, dest), i|
      alias_chain = (1..i+1).map { |n| "s#{n}" }

      from_part = +"segments s1"
      (1...alias_chain.size).each do |j|
        prev = alias_chain[j-1]
        curr = alias_chain[j]
        curr_dest = legs[j][1]

        from_part << <<-SQL.squish.prepend(" ")
          JOIN segments #{curr}
            ON #{curr}.origin_iata = #{prev}.destination_iata
           AND #{curr}.destination_iata = '#{curr_dest}'
           AND #{curr}.std BETWEEN #{prev}.sta + (#{@min_connection} || ' minutes')::interval
                              AND #{prev}.sta + (#{@max_connection} || ' minutes')::interval
        SQL
      end

      where_part = []
      where_part << "s1.airline = $1"
      where_part << "s1.origin_iata = '#{legs[0][0]}'"
      where_part << "s1.destination_iata = '#{legs[0][1]}'"
      where_part << "s1.std BETWEEN $2 AND $3"

      queries << <<-SQL.squish
        SELECT #{alias_chain.last}.*
        FROM #{from_part}
        WHERE #{where_part.join(" AND ")}
      SQL
    end

    sql = queries.join(" UNION ALL ")

    [ sql, query_params ]
  end

  def query_params
    [ @carrier, @departure_from, @departure_to ]
  end
end

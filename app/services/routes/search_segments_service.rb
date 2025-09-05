module Routes
  class SearchSegmentsService
    MIN_CONNECTION_TIME = 8.hours
    MAX_CONNECTION_TIME = 48.hours

    def initialize(carrier:, departure_from:, departure_to:, segment_paths:)
      @carrier = carrier
      @departure_from = departure_from
      @departure_to = departure_to
      @segment_paths = segment_paths
    end

    def perform
      find_segments(
        segment_paths: @segment_paths,
        segment_departure_from: @departure_from,
        segment_departure_to: @departure_to
      )
    end

    def segments
      @segments ||= []
    end

    private

    def find_segments(segment_paths:, segment_departure_from:, segment_departure_to:, previous_segments: [])
      segment_paths.each do |segment_path|
        path_segments = Segment.by_airline(@carrier)
                          .by_path(segment_path[0], segment_path[1])
                          .departure_between(segment_departure_from, segment_departure_to)
                          .arrival_before(@departure_to)

        path_segments.each do |path_segment|
          current_segments = previous_segments + [path_segment]
          if segment_paths.size == 1
            segments << current_segments
          else
            next_departure_from = path_segment.sta + MIN_CONNECTION_TIME
            next_departure_to = path_segment.sta + MAX_CONNECTION_TIME

            find_segments(
              segment_paths: segment_paths[1..-1],
              segment_departure_from: next_departure_from,
              segment_departure_to: next_departure_to,
              previous_segments: current_segments
            )
          end
        end
      end
    end
  end
end

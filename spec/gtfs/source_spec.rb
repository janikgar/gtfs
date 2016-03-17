require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::Source do
  let(:source_root) { File.join(File.expand_path(File.dirname(__FILE__)), '..') }
  let(:source_valid) { File.join(source_root, 'fixtures', 'valid_gtfs') }
  let(:source_valid_zip) { File.join(source_root, 'fixtures', 'example.zip') }
  let(:source_nested_zip) { File.join(source_root, 'fixtures', 'example_nested.zip') }
  let(:source_missing) { File.join(source_root, 'fixtures', 'not_here') }
  let(:source_missing_required_files) { File.join(source_root, 'fixtures', 'missing_files') }

  describe '.find_nested_gtfs' do
    it 'finds root sources' do
      GTFS::Source.find_nested_gtfs(source_valid_zip).should =~ ["/"]
    end

    it 'finds nested sources' do
      GTFS::Source.find_nested_gtfs(source_nested_zip).should =~ ["/example_nested/example", "/example_nested/nested/example.zip/"]
    end
  end

  # describe '.build' do
  #   let(:opts) {{}}
  #   let(:data_source) { source_valid }
  #   subject {GTFS::Source.build(data_source, opts)}
  #
  #   context 'with a url as a data root' do
  #     use_vcr_cassette('valid_gtfs_uri')
  #     let(:data_source) {'http://dl.dropbox.com/u/416235/work/valid_gtfs.zip'}
  #     it {should be_instance_of GTFS::URLSource}
  #     its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
  #   end
  #
  #   context 'with a file path as a data root' do
  #     let(:data_source) { source_valid }
  #     it {should be_instance_of GTFS::Source}
  #     its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
  #   end
  #
  #   context 'with a file object as a data root' do
  #     let(:data_source) {File.open(source_valid)}
  #     it {should be_instance_of GTFS::Source}
  #     its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
  #   end
  #
  #   context 'with options to disable strict checks' do
  #     let(:opts) {{strict: false}}
  #     its(:options) {should == {strict: false}}
  #   end
  # end

  describe '#new' do
    subject {lambda{GTFS::Source.new(source_path)}}

    context 'with a source path' do
      let(:source_path) {source_valid}
      it {should_not raise_error(GTFS::InvalidSourceException)}
    end

    context 'with a source path that is invalid' do
      let(:source_path) {source_missing}
      it {should raise_error(GTFS::InvalidSourceException)}
    end

    context 'with a source path that is missing files' do
      let(:source_path) {source_missing}
      it {should raise_error(GTFS::InvalidSourceException)}
    end
  end

  describe 'row_count' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'returns approximate row count' do
      source.row_count('stop_times.txt').should eq 9
    end
  end

  describe 'load_graph' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'test' do
      source.load_graph
    end
  end

  describe '#file_present?' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'should return true if file is present' do
      source.file_present?('agency.txt').should be true
    end
    it 'should return false if a file is not present' do
      source.file_present?('missing.txt').should be false
    end
  end

  describe '#required_files_present?' do
    let(:all_files) {['agency.txt', 'stops.txt', 'routes.txt', 'trips.txt', 'stop_times.txt', 'calendar.txt', 'calendar_dates.txt']}
    it 'should be true when all required files present' do
      GTFS::Source.required_files_present?(all_files).should be true
    end

    it 'should be false when missing required files' do
      GTFS::Source.required_files_present?(all_files - ['stops.txt']).should be false
    end

    it 'should be accept calendar.txt or calendar_dates.txt' do
      GTFS::Source.required_files_present?(all_files - ['calendar.txt']).should be true
      GTFS::Source.required_files_present?(all_files - ['calendar_dates.txt']).should be true
      GTFS::Source.required_files_present?(all_files - ['calendar.txt', 'calendar_dates.txt']).should be false
    end

  end

  describe '#valid?' do
    it 'should be true when all required files present' do
      source = GTFS::Source.build(source_valid)
      source.valid?.should be true
    end
  end

  describe '#load_shapes' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'should load shapes when file present' do
      shapes = source.load_shapes
      shapes.size.should > 0
    end
    # it 'should return nil when file not present' do
    #   File.unlink(source.send(:file_path, 'shapes.txt'))
    #   shapes = source.load_shapes
    #   shapes.should be nil
    # end
    it '#shape_line should returns array of points' do
      source.shape_line('63542').size.should be 9
    end
  end

  describe '#load_service_periods' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'should return ServicePeriods' do
      source.load_service_periods.size.should > 0
    end
    # it 'should handle missing calendar/calendar_dates' do
    #   File.unlink(source.send(:file_path, 'calendar.txt'))
    #   source.load_service_periods.size.should > 0
    # end
    it '#service_period returns ServicePeriod' do
      source.service_period('1').class.should be GTFS::ServicePeriod
    end
  end

  describe '#service_period_range' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'calculates min and max service dates using both calendars' do
      start_date, end_date = source.service_period_range
      start_date.should eq Date.parse('2012-01-29')
      end_date.should eq Date.parse('2012-06-16')
    end
  end

  describe 'each_entity' do
    let(:source) {GTFS::Source.build(source_valid)}
    it 'entities maintain reference to feed' do
      source.agencies.first.feed.should be source
    end
  end

  describe '#agencies' do
    subject {source.agencies}

    context 'when the source has agencies' do
      let(:source) {GTFS::Source.build(source_valid)}

      it {should_not be_empty}
      its(:first) {should be_an_instance_of(GTFS::Agency)}
    end
  end

  describe '#stops' do
  end

  describe '#routes' do
    context 'when the source is missing routes' do
      let(:source) { GTFS::Source.build source_missing_required_files }

      it do
        expect { source.routes }.to raise_exception GTFS::InvalidSourceException
      end
    end
  end

  describe '#trips' do
  end

  describe '#stop_times' do
  end
end

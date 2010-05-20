# encoding: UTF-8
module Wice
  module GridViewHelper

    # View helper for rendering the grid.
    #
    # The first parameter is a grid object returned by +initialize_grid+ in the controller.
    #
    # The second parameter is a hash of options:
    # * <tt>:table_html_attrs</tt> - a hash of HTML attributes to be included into the <tt>table</tt> tag.
    # * <tt>:class</tt> - a shortcut for <tt>:table_html_attrs => {:class => 'css_class'}</tt>
    # * <tt>:header_tr_html_attrs</tt> - a hash of HTML attributes to be included into the first <tt>tr</tt> tag
    #   (or two first <tt>tr</tt>'s if the filter row is present).
    # * <tt>:show_filters</tt> - defines when the filter is shown. Possible values are:
    #   * <tt>:when_filtered</tt> - the filter is shown when the current table is the result of filtering
    #   * <tt>:always</tt> or <tt>true</tt>  - show the filter always
    #   * <tt>:no</tt> or <tt>false</tt>     - never show the filter
    # * <tt>:upper_pagination_panel</tt> - a boolean value which defines whether there is an additional pagination
    #   panel on top of the table. By default it is false.
    # * <tt>:extra_request_parameters</tt> - a hash which will be added as additional HTTP request parameters to all links generated by the grid,
    #   be it sorting links, filters, or the 'Reset Filter' icon. Please note that WiceGrid respects and retains all request parameters already
    #   present in the URL which formed the page, so there is no need to enumerate them in <tt>:extra_request_parameters</tt>. A typical
    #   usage of <tt>:extra_request_parameters</tt> is a page with javascript tabs - changing the active tab does not reload the page, but if
    #   one such tab contains a WiceGrid, it could be required that if the user orders or filters the grid, the result page should have the tab
    #   with the grid activated. For this we need to send an additional parameter specifying from which tab the request was generated.
    # * <tt>:sorting_dependant_row_cycling</tt> - When set to true (by default it is false) the row styles +odd+ and +even+ will be changed
    #   only when the content of the cell belonging to the sorted column changes. In other words, rows with identical values in the ordered
    #   column will have the same style (color).
    # * <tt>:erb_mode</tt> - can be <tt>true</tt> or <tt>false</tt>. Defines the style of the helper method in the view. The default is <tt>false</tt>.
    # * <tt>:allow_showing_all_records</tt> - allow or prohibit the "All Records" mode.
    # * <tt>:hide_reset_button</tt> - Do not show the Filter Reset button.
    # * <tt>:hide_submit_button</tt> - Do not show the Filter Submit button.
    #   Please read README for more insights.
    #
    # The block contains definitions of grid columns using the +column+ method sent to the object yielded into the block. In other words,
    # the value returned by each of the blocks defines the content of a cell, the first block is called for cells of the first column
    # for each row (each ActiveRecord instance), the second block is called for cells of the second column, and so on. See the example:
    #
    #   <%= grid(@accounts_grid, :table_html_attrs => {:class => 'grid_style', :id => 'accounts_grid'}, :header_tr_html_attrs => {:class => 'grid_headers'}) do |g|
    #
    #     g.column :column_name => 'Username', :attribute_name => 'username' do |account|
    #       account.username
    #     end
    #
    #     g.column :column_name => 'application_account.field.identity_id'._, :attribute_name => 'firstname', :model_class =>  Person do |account|
    #       link_to(account.identity.name, identity_path(account.identity))
    #     end
    #
    #     g.column do |account|
    #       link_to('Edit', edit_account_path(account))
    #     end
    #
    #   end -%>
    #
    # The helper may have two styles defined by the +erb_mode+ parameter to the +initialize_grid+ in the contoller.
    # By default (<tt>erb_mode = false</tt>) this is a simple helper surrounded by <tt><%=</tt> and <tt>%></tt>:
    #
    #     <%= grid(@countries_grid) do |g|
    #
    #       g.column :column_name => 'Name', :attribute_name => 'name' do |country|
    #         link_to(country.name, country_path(country))
    #       end
    #
    #       g.column :column_name => 'Numeric Code', :attribute_name => 'numeric_code' do |country|
    #         country.numeric_code
    #       end
    #
    #     end -%>
    #
    #
    #
    # The second style (<tt>erb_mode = true</tt>) is called <em>ERB mode</em> and it allows to embed any ERB content inside blocks,
    # which is basically the style of the
    # <tt>form_for</tt> helper, only <tt>form_for</tt> takes one block, while inside the <tt>grid</tt> block there are other method calls taking
    # blocks as parameters:
    #
    #     <% grid(@countries_grid) do |g|
    #
    #       <% g.column :column_name => 'Name', :attribute_name => 'name' do |country| %>
    #         <b>Name: <%= link_to(country.name, country_path(country)) %></b>
    #       <% end %>
    #
    #       <% g.column :column_name => 'Numeric Code', :attribute_name => 'numeric_code' do |country| %>
    #         <i>Numeric Code: <%= country.numeric_code %></i>
    #       <% end %>
    #
    #     <% end -%>
    #
    # This mode can be usable if you like to have much HTML code inside cells.
    #
    # Please remember that in this mode the helper opens with <tt><%</tt> instead of <tt><%=</tt>, similar to <tt>form_for</tt>.
    #
    # Defaults for parameters <tt>:show_filters</tt> and <tt>:upper_pagination_panel</tt>
    # can be changed in <tt>lib/wice_grid_config.rb</tt> using constants <tt>Wice::Defaults::SHOW_FILTER</tt> and
    # <tt>WiceGrid::Defaults::SHOW_UPPER_PAGINATION_PANEL</tt>, this is convenient if you want to set a project wide setting
    # without having to repeat it for every grid instance.
    #
    # Pease read documentation about the +column+ method to achieve the enlightenment.

    def grid(grid, opts = {}, &block)
      unless grid.class == WiceGrid
        raise WiceGridArgumentError.new("The first argument for the grid helper must be an instance of the WiceGrid class")
      end

      if grid.output_buffer
        if grid.output_buffer == true
          raise  WiceGridException.new("Second occurence of grid helper with the same grid object. " +
                                "Did you intend to use detached filters and forget to define them?")
        else
          return grid.output_buffer
        end
      end

      options = {
        :allow_showing_all_records     => Defaults::ALLOW_SHOWING_ALL_QUERIES,
        :class                         => nil,
        :erb_mode                      => Defaults::ERB_MODE,
        :extra_request_parameters      => {},
        :header_tr_html_attrs          => {},
        :hide_reset_button             => false,
        :hide_submit_button            => false,
        :show_filters                  => Defaults::SHOW_FILTER,
        :sorting_dependant_row_cycling => false,
        :table_html_attrs              => {},
        :upper_pagination_panel        => Defaults::SHOW_UPPER_PAGINATION_PANEL
      }

      opts.assert_valid_keys(options.keys)

      options.merge!(opts)

      options[:show_filters] = :no     if options[:show_filters] == false
      options[:show_filters] = :always if options[:show_filters] == true

      options[:table_html_attrs].add_or_append_class_value!('wice_grid', true)

      if options[:class]
        options[:table_html_attrs].add_or_append_class_value!(options[:class])
        options.delete(:class)
      end

      rendering = GridRenderer.new(grid)
      rendering.erb_mode = options[:erb_mode]

      block.call(rendering) # calling block containing column() calls

      reuse_last_column_for_filter_buttons =
        Defaults::REUSE_LAST_COLUMN_FOR_FILTER_ICONS && rendering.last_column_for_html.capable_of_hosting_filter_related_icons?

      if grid.output_csv?
        content = grid_csv(grid, rendering)
      else
        # If blank_slate is defined we don't show any grid at all
        if rendering.blank_slate_handler &&  grid.resultset.size == 0 && ! grid.filtering_on?
          content = generate_blank_slate(grid, rendering)
          return prepare_result(rendering, grid, content, block)
        end

        content = grid_html(grid, options, rendering, reuse_last_column_for_filter_buttons)
      end

      if grid.after
        lazy_grid_caller = lambda{grid.send(:resultset_without_paging_with_user_filters)}
        if grid.after.is_a?(Proc)
          grid.after.call(lazy_grid_caller)
        elsif grid.after.is_a?(Symbol)
          controller.send(grid.after, lazy_grid_caller)
        end
      end
      grid.view_helper_finished = true
      prepare_result(rendering, grid, content, block)
    end

    def prepare_result(rendering, grid, content, block) #:nodoc:
      if rendering.erb_mode
        # true in this case is a sign that grid_html has run in a normal mode, i.e. without detached filters
        if grid.output_buffer.nil? || grid.output_buffer == true
          content = content.to_s
          if Rails.respond_to?(:version) && Rails.version.to_f >= 2.2
            return concat(content)
          else
            return concat(content, block.binding)
          end
        else
          # this way we're sending an empty string and setting flag stubborn_output_mode of GridOutputBuffer to false
          return grid.output_buffer.to_s
        end
      else
        return content
      end
    end


    def generate_blank_slate(grid, rendering) #:nodoc:
      buff = GridOutputBuffer.new

      buff <<  if rendering.blank_slate_handler.is_a?(Proc)
        call_block_as_erb_or_ruby(rendering, rendering.blank_slate_handler, nil)
      elsif rendering.blank_slate_handler.is_a?(Hash)
        render(rendering.blank_slate_handler)
      else
        rendering.blank_slate_handler
      end

      if rendering.find_one_for(:in_html){|column| column.detach_with_id}
        buff.stubborn_output_mode = true
        buff.return_empty_strings_for_nonexistent_filters = true
        grid.output_buffer   = buff
      end
      buff
    end

    def call_block_as_erb_or_ruby(rendering, block, ar)  #:nodoc:
      if rendering.erb_mode
        capture(ar, &block)
      else
        block.call(ar)
      end
    end

    # the longest method? :(
    def grid_html(grid, options, rendering, reuse_last_column_for_filter_buttons) #:nodoc:

      table_html_attrs, header_tr_html_attrs = options[:table_html_attrs], options[:header_tr_html_attrs]

      cycle_class = nil
      sorting_dependant_row_cycling = options[:sorting_dependant_row_cycling]

      content = GridOutputBuffer.new
      # Ruby 1.9.1
      content.force_encoding('UTF-8') if content.respond_to?(:force_encoding)

      content << %!<div class="wice_grid_container" id="#{grid.name}"><div id="#{grid.name}_title">!
      content << content_tag(:h3, grid.saved_query.name) if grid.saved_query
      content << "</div><table #{tag_options(table_html_attrs, true)}>"
      content << "<thead>"

      no_filters_at_all = (options[:show_filters] == :no || rendering.no_filter_needed?) ? true: false

      if no_filters_at_all
        no_rightmost_column = no_filter_row = no_filters_at_all
      else
        no_rightmost_column = no_filter_row = (options[:show_filters] == :no || rendering.no_filter_needed_in_main_table?) ? true: false
      end

      no_rightmost_column = true if reuse_last_column_for_filter_buttons

      pagination_panel_content_html, pagination_panel_content_js = nil, nil
      if options[:upper_pagination_panel]
        content << rendering.pagination_panel(no_rightmost_column){
          pagination_panel_content_html, pagination_panel_content_js = pagination_panel_content(grid, 
            options[:extra_request_parameters], options[:allow_showing_all_records])
          pagination_panel_content_html
        }
      end

      title_row_attrs = header_tr_html_attrs.clone
      title_row_attrs.add_or_append_class_value!('wice_grid_title_row', true)

      content << %!<tr #{tag_options(title_row_attrs, true)}>!

      filter_row_id = grid.name + '_filter_row'

      # first row of column labels with sorting links

      filter_shown = if options[:show_filters] == :when_filtered
        grid.filtering_on?
      elsif options[:show_filters] == :always
        true
      end

      cached_javascript = []

      rendering.each_column_aware_of_one_last_one(:in_html) do |column, last|
        
        column_name = column.column_name
        if column_name.is_a? Array
          column_name, js = column_name
          cached_javascript << js
        end
        
        if column.attribute_name && column.allow_ordering

          css_class = grid.filtered_by?(column) ? 'active_filter' : nil

          direction = 'asc'
          link_style = nil
          if grid.ordered_by?(column)
            css_class = css_class.nil? ? 'sorted' : css_class + ' sorted'
            link_style = grid.order_direction
            direction = 'desc' if grid.order_direction == 'asc'
          end

          col_link = link_to(
            column_name,
            rendering.column_link(column, direction, params, options[:extra_request_parameters]),
            :class => link_style)
          content << content_tag(:th, col_link, Hash.make_hash(:class, css_class))
          column.css_class = css_class
        else
          if reuse_last_column_for_filter_buttons && last
            content << content_tag(:th,
              hide_show_icon(filter_row_id, grid, filter_shown, no_filter_row, options[:show_filters], rendering),
              :class => 'hide_show_icon'
            )
          else
            content << content_tag(:th, column_name)
          end
        end
      end

      content << content_tag(:th,
        hide_show_icon(filter_row_id, grid, filter_shown, no_filter_row, options[:show_filters], rendering),
        :class => 'hide_show_icon'
      ) unless no_rightmost_column

      content << '</tr>'
      # rendering first row end


      unless no_filters_at_all # there are filters, we don't know where, in the table or detached
        if no_filter_row # they are all detached
          content.stubborn_output_mode = true
          rendering.each_column(:in_html) do |column|
            if column.filter_shown?
              filter_html_code, filter_js_code = column.render_filter
              cached_javascript << filter_js_code
              content.add_filter(column.detach_with_id, filter_html_code)
            end
          end

        else # some filters are present in the table

          filter_row_attrs = header_tr_html_attrs.clone
          filter_row_attrs.add_or_append_class_value!('wice_grid_filter_row', true)
          filter_row_attrs['id'] = filter_row_id

          content << %!<tr #{tag_options(filter_row_attrs, true)} !
          content << 'style="display:none"' unless filter_shown
          content << '>'

          rendering.each_column_aware_of_one_last_one(:in_html) do |column, last|
            if column.filter_shown?

              filter_html_code, filter_js_code = column.render_filter
              cached_javascript << filter_js_code
              if column.detach_with_id
                content.stubborn_output_mode = true
                content << content_tag(:th, '', Hash.make_hash(:class, column.css_class))
                content.add_filter(column.detach_with_id, filter_html_code)
              else
                content << content_tag(:th, filter_html_code, Hash.make_hash(:class, column.css_class))
              end
            else
              if reuse_last_column_for_filter_buttons && last
                content << content_tag(:th,
                  reset_submit_buttons(options, grid, rendering),
                  Hash.make_hash(:class, column.css_class).add_or_append_class_value!('filter_icons')
                )
              else
                content << content_tag(:th, '', Hash.make_hash(:class, column.css_class))
              end
            end
          end
          unless no_rightmost_column
            content << content_tag(:th, reset_submit_buttons(options, grid, rendering), :class => 'filter_icons' )
          end
          content << '</tr>'
        end
      end

      rendering.each_column(:in_html) do |column|
        unless column.css_class.blank?
          column.td_html_attrs.add_or_append_class_value!(column.css_class)
        end
      end

      content << '</thead><tfoot>'
      content << rendering.pagination_panel(no_rightmost_column){
        if pagination_panel_content_html
          pagination_panel_content_html
        else
          pagination_panel_content_html, pagination_panel_content_js = 
            pagination_panel_content(grid, options[:extra_request_parameters], options[:allow_showing_all_records])
          pagination_panel_content_html
        end
      }
      content << '</tfoot><tbody>'
      cached_javascript << pagination_panel_content_js if pagination_panel_content_js

      # rendering  rows
      cell_value_of_the_ordered_column = nil
      previous_cell_value_of_the_ordered_column = nil

      grid.each do |ar| # rows

        before_row_output = if rendering.before_row_handler
          call_block_as_erb_or_ruby(rendering, rendering.before_row_handler, ar)
        else
          nil
        end

        after_row_output = if rendering.after_row_handler
          call_block_as_erb_or_ruby(rendering, rendering.after_row_handler, ar)
        else
          nil
        end

        row_content = ''
        rendering.each_column(:in_html) do |column|
          cell_block = column.cell_rendering_block

          opts = column.td_html_attrs.clone
          
          column_block_output = if column.class == Wice::ActionViewColumn
            cell_block.call(ar, params)
          else
            call_block_as_erb_or_ruby(rendering, cell_block, ar)
          end

          if column_block_output.kind_of?(Array)

            unless column_block_output.size == 2
              raise WiceGridArgumentError.new('When WiceGrid column block returns an array it is expected to contain 2 elements only - '+
                'the first is the contents of the table cell and the second is a hash containing HTML attributes for the <td> tag.')
            end

            column_block_output, additional_opts = column_block_output

            unless additional_opts.is_a?(Hash)
              raise WiceGridArgumentError.new('When WiceGrid column block returns an array its second element is expected to be a ' +
                "hash containing HTML attributes for the <td> tag. The returned value is #{additional_opts.inspect}. Read documentation.")
            end

            additional_css_class = nil
            if additional_opts.has_key?(:class)
              additional_css_class = additional_opts[:class]
              additional_opts.delete(:class)
            elsif additional_opts.has_key?('class')
              additional_css_class = additional_opts['class']
              additional_opts.delete('class')
            end
            opts.merge!(additional_opts)
            opts.add_or_append_class_value!(additional_css_class) unless additional_css_class.blank?
          end

          if sorting_dependant_row_cycling && column.attribute_name && grid.ordered_by?(column)
            cell_value_of_the_ordered_column = column_block_output
          end
          row_content += content_tag(:td, column_block_output, opts)
        end

        row_attributes = rendering.get_row_attributes(ar)

        if sorting_dependant_row_cycling
          cycle_class = cycle('odd', 'even', :name => grid.name) if cell_value_of_the_ordered_column != previous_cell_value_of_the_ordered_column
          previous_cell_value_of_the_ordered_column = cell_value_of_the_ordered_column
        else
          cycle_class = cycle('odd', 'even', :name => grid.name)
        end

        row_attributes.add_or_append_class_value!(cycle_class)

        content << before_row_output if before_row_output
        content << "<tr #{tag_options(row_attributes)}>#{row_content}"
        content << content_tag(:td, '') unless no_rightmost_column
        content << after_row_output if after_row_output
        content << '</tr>'
      end

      content << '</tbody></table></div>'

      base_link_for_filter, base_link_for_show_all_records = rendering.base_link_for_filter(controller, options[:extra_request_parameters])

      link_for_export      = rendering.link_for_export(controller, 'csv', options[:extra_request_parameters])

      parameter_name_for_query_loading = {grid.name => {:q => ''}}.to_query

      prototype_and_js_version_check = if ENV['RAILS_ENV'] == 'development'
        %$ if (typeof(WiceGridProcessor) == "undefined"){\n$ +
        %$   alert('wice_grid.js not loaded, WiceGrid cannot proceed! ' +\n$ +
        %$     'Please make sure that you include Prototype and WiceGrid javascripts in your page. ' +\n$ +
        %$     'Use <%= include_wice_grid_assets %> or <%= include_wice_grid_assets(:include_calendar => true) %> ' +\n$ +
        %$     'for WiceGrid javascripts and assets.')\n$ +
        %$ } else if ((typeof(WiceGridProcessor._version) == "undefined") || ( WiceGridProcessor._version != "0.4.1")) {\n$ +
        %$    alert("wice_grid.js in your /public is outdated, please run\\n ./script/generate wice_grid_assets\\nto update it.");\n$ +
        %$ }\n$
      else
        ''
      end

      if rendering.show_hide_button_present
        cached_javascript << %/ $('#{grid.name}_show_icon').observe('click', function(){\n/+
                             %/   Element.toggle('#{grid.name}_show_icon');\n/+
                             %/   Element.toggle('#{grid.name}_hide_icon');\n/+
                             %/   $('#{filter_row_id}').show();\n/+
                             %/ })\n/+
                             %/ $('#{grid.name}_hide_icon').observe('click', function(){\n/+
                             %/   Element.toggle('#{grid.name}_show_icon');\n/+
                             %/   Element.toggle('#{grid.name}_hide_icon');\n/+
                             %/   $('#{filter_row_id}').hide();\n/+
                             %/ })\n/
      end

      if rendering.reset_button_present
        cached_javascript << %/ $$('div##{grid.name}.wice_grid_container .reset').each(function(e){\n/+
                             %/   e.observe('click', function(){\n/+
                             %/     #{reset_grid_javascript(grid)};\n/+
                             %/   })\n/+
                             %/ })\n/
      end
      
      if rendering.submit_button_present
        cached_javascript << %/ $$('div##{grid.name}.wice_grid_container .submit').each(function(e){\n/+
                             %/   e.observe('click', function(){\n/+
                             %/     #{submit_grid_javascript(grid)};\n/+
                             %/   })\n/+
                             %/ })\n/ 
      end

      if rendering.contains_a_text_input?
        cached_javascript <<
          %! $$('div##{grid.name}.wice_grid_container .wice_grid_filter_row input[type=text]').each(function(e){\n! +
          %!   e.observe('keydown', function(event){\n! +
          %!     if (event.keyCode == 13) {#{grid.name}.process()}\n! +
          %!   })\n! +
          %! }) !
      end

      content << javascript_tag(
        %/ document.observe("dom:loaded", function() {\n/ +
        %/ #{prototype_and_js_version_check}\n/ +
        %/ window['#{grid.name}'] = new WiceGridProcessor('#{grid.name}', '#{base_link_for_filter}',\n/ +
        %/  '#{base_link_for_show_all_records}', '#{link_for_export}', '#{parameter_name_for_query_loading}', '#{ENV['RAILS_ENV']}');\n/ +
        if no_filters_at_all
          ''
        else
          rendering.select_for(:in_html) do |vc|
            vc.attribute_name and not vc.no_filter
          end.collect{|column| column.yield_javascript}.join("\n")
        end +
        "\n" + cached_javascript.compact.join('') +
        '})'
      )

      if content.stubborn_output_mode
        grid.output_buffer = content
      else
        # this will serve as a flag that the grid helper has already processed the grid but in a normal mode,
        # not in the mode with detached filters.
        grid.output_buffer = true
      end
      return content
    end

    def hide_show_icon(filter_row_id, grid, filter_shown, no_filter_row, show_filters, rendering)  #:nodoc:
      grid_name = grid.name
      no_filter_opening_closing_icon = (show_filters == :always) || no_filter_row

      styles = ["display: block;", "display: none;"]
      styles.reverse! unless filter_shown


      if no_filter_opening_closing_icon
        hide_icon = show_icon = ''
      else


        rendering.show_hide_button_present = true
        filter_tooltip = WiceGridNlMessageProvider.get_message(:HIDE_FILTER_TOOLTIP)

        hide_icon = content_tag(:span,
          image_tag(Defaults::SHOW_HIDE_FILTER_ICON,
            :title => filter_tooltip,
            :alt   => filter_tooltip),
          :id => grid_name + '_hide_icon',
          :style => styles[0],
          :class => 'clickable'
        )


        filter_tooltip = WiceGridNlMessageProvider.get_message(:SHOW_FILTER_TOOLTIP)

        show_icon = content_tag(:span,
          image_tag(Defaults::SHOW_HIDE_FILTER_ICON,
            :title => filter_tooltip,
            :alt   => filter_tooltip),
          :id => grid_name + '_show_icon',
          :style => styles[1],
          :class => 'clickable'
        )
        
        hide_icon + show_icon
      end
    end

    def reset_submit_buttons(options, grid, rendering)  #:nodoc:
      if options[:hide_submit_button]
        ''
      else
        rendering.submit_button_present = true
        filter_tooltip = WiceGridNlMessageProvider.get_message(:FILTER_TOOLTIP)
        image_tag(Defaults::FILTER_ICON, :title => filter_tooltip, :alt => filter_tooltip, :class => 'submit clickable')
      end + ' ' +
      if options[:hide_reset_button]
        ''
      else
        rendering.reset_button_present = true
        filter_tooltip = WiceGridNlMessageProvider.get_message(:RESET_FILTER_TOOLTIP)
        image_tag(Defaults::RESET_ICON, :title => filter_tooltip, :alt => filter_tooltip, :class => 'reset clickable')
      end
    end

    # Renders a detached filter. The parameters are:
    # * +grid+ the WiceGrid object
    # * +filter_key+ an identifier of the filter specified in the column declaration by parameter +:detach_with_id+
    def grid_filter(grid, filter_key)
      unless grid.kind_of? WiceGrid
        raise WiceGridArgumentError.new("submit_grid_javascript: the parameter must be a WiceGrid instance.")
      end
      if grid.output_buffer.nil?
        raise WiceGridArgumentError.new("grid_filter: You have attempted to run 'grid_filter' before 'grid'. Read about detached filters in the documentation.")
      end
      if grid.output_buffer == true
        raise WiceGridArgumentError.new("grid_filter: You have defined no detached filters, or you try use detached filters with" +
          ":show_filters => :no (set :show_filters to :always in this case). Read about detached filters in the documentation.")
      end

      grid.output_buffer.filter_for filter_key
    end

    # Returns javascript which applies current filters. The parameter is a WiceGrid instance. Use it with +button_to_function+ to create
    # your Submit button.
    def submit_grid_javascript(grid)
      unless grid.kind_of? WiceGrid
        raise WiceGridArgumentError.new("submit_grid_javascript: the parameter must be a WiceGrid instance.")
      end
      "#{grid.name}.process()"
    end

    # Returns javascript which resets the grid, clearing the state of filters.
    # The parameter is a WiceGrid instance. Use it with +button_to_function+ to create
    # your Reset button.
    def reset_grid_javascript(grid)
      unless grid.kind_of? WiceGrid
        raise WiceGridArgumentError.new("reset_grid_javascript: the parameter must be a WiceGrid instance.")
      end
      "#{grid.name}.reset()"
    end

    def grid_csv(grid, rendering) #:nodoc:


      field_separator = (grid.export_to_csv_enabled && grid.export_to_csv_enabled.is_a?(String)) ? grid.export_to_csv_enabled : ','
      spreadsheet = ::Wice::Spreadsheet.new(grid.name, field_separator)

      # columns
      spreadsheet << rendering.column_labels(:in_csv)

      # rendering  rows
      grid.each do |ar| # rows
        row = []

        rendering.each_column(:in_csv) do |column|
          cell_block = column.cell_rendering_block

          column_block_output = call_block_as_erb_or_ruby(rendering, cell_block, ar)

          if column_block_output.kind_of?(Array)
            column_block_output, additional_opts = column_block_output
          end

          row << column_block_output
        end
        spreadsheet << row
      end
      spreadsheet.close
      return spreadsheet.path
    end

    def pagination_panel_content(grid, extra_request_parameters, allow_showing_all_records) #:nodoc:
      extra_request_parameters = extra_request_parameters.clone
      if grid.saved_query
        extra_request_parameters["#{grid.name}[q]"] = grid.saved_query.id
      end

      html, js = pagination_info(grid, allow_showing_all_records)

      [will_paginate(grid.resultset, 
        :previous_label => WiceGridNlMessageProvider.get_message(:PREVIOUS_LABEL),
        :next_label     => WiceGridNlMessageProvider.get_message(:NEXT_LABEL),
        :param_name     => "#{grid.name}[page]", 
        :params         => extra_request_parameters).to_s +
        ' <div class="pagination_status">' + html + '</div>', js]
    end


    def show_all_link(collection_total_entries, parameters, grid_name) #:nodoc:

      message = WiceGridNlMessageProvider.get_message(:ALL_QUERIES_WARNING)
      confirmation = collection_total_entries > Defaults::START_SHOWING_WARNING_FROM ? "if (confirm('#{message}'))" : ''
      js = %/ $$('div##{grid_name}.wice_grid_container .show_all_link').each(function(e){\n/ +
           %/   e.observe('click', function(){\n/ +
           %/     #{confirmation} #{grid_name}.reload_page_for_given_grid_state(#{parameters.to_json})\n/ +
           %/   })\n/ +
           %/ })\n/

      tooltip = WiceGridNlMessageProvider.get_message(:SHOW_ALL_RECORDS_TOOLTIP)
      html = %/<span class="show_all_link"><a href="#" title="#{tooltip}">/ +
        WiceGridNlMessageProvider.get_message(:SHOW_ALL_RECORDS_LABEL) +
        '</a></span>'

      [html, js]
    end

    def back_to_pagination_link(parameters, grid_name) #:nodoc:
      pagination_override_parameter_name = "#{grid_name}[pp]"
      parameters = parameters.reject{|k, v| k == pagination_override_parameter_name}

      js = %/ $$('div##{grid_name}.wice_grid_container .show_all_link').each(function(e){\n/ +
           %/   e.observe('click', function(){\n/ +
           %/     #{grid_name}.reload_page_for_given_grid_state(#{parameters.to_json})\n/ +
           %/   })\n/ +
           %/ })\n/

      tooltip = WiceGridNlMessageProvider.get_message(:SWITCH_BACK_TO_PAGINATED_MODE_TOOLTIP)
      html = %/ <span class="show_all_link"><a href="#" title="#{tooltip}">/ +
        WiceGridNlMessageProvider.get_message(:SWITCH_BACK_TO_PAGINATED_MODE_LABEL) +
        '</a></span>'
      [html, js]
    end

    def pagination_info(grid, allow_showing_all_records)  #:nodoc:
      collection = grid.resultset

      collection_total_entries = collection.total_entries
      collection_total_entries_str = collection_total_entries.to_s
      parameters = grid.get_state_as_parameter_value_pairs

      js = nil
      html = if (collection.total_pages < 2 && collection.length == 0)
        '0'
      else
        parameters << ["#{grid.name}[pp]", collection_total_entries_str]

        "#{collection.offset + 1}-#{collection.offset + collection.length} / #{collection_total_entries_str} " +
          if (! allow_showing_all_records) || collection_total_entries <= collection.length
            ''
          else
            res, js = show_all_link(collection_total_entries, parameters, grid.name)
            res
          end
      end +
      if grid.all_record_mode?
        res, js = back_to_pagination_link(parameters, grid.name)
        res
      else
        ''
      end
      
      [html, js]
    end

    if self.respond_to?(:safe_helper)
      safe_helper :grid_filter
    end

  end
end
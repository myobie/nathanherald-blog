// for right now, I am just running straight out of the gate, not on load
// $(function() {
  
  $('.review p.rating').each(function(i) {
    
    var span = $(this).find('span');
    span = span[0];
    var rating = parseFloat($(span).html());
    var star_width = 15;
    var space_width = 4;
    var total_stars = 5;
    var max_rating = 5;
    var spaces = Math.floor(rating);
    
    var this_width = (star_width * rating) + (space_width * spaces);
    this_width = Math.round(this_width); // round to the nearest pixel
    
    var html = "<div class=\"stars-off\"> \
                  <div class=\"stars-on\" style=\"width:{this_width}px\"> \
                    {rating_amount} \
                  </div> \
                </div>"
    
    html = html.replace("{rating_amount}", rating).replace("{this_width}", this_width);
    
    $(this).replaceWith(html);
  });
  
// });
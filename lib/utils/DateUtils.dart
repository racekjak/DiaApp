String getDate(DateTime time) {
  var date = "";
  if (time != null) {
    var dateMonth = (time.toString().split('-')[1].split('-')[0]);
    var dateDay = (time.toString().split('-')[2].split(' ')[0]);
    var year = time.year;
    date = dateDay + "." + dateMonth + "." + year.toString();
  }
  return date;
}

String getTime(DateTime time) {
  var dateTime = "";
  if (time != null) {
    dateTime = time.toString().split(' ')[1].split('.')[0];
  }
  return dateTime;
}

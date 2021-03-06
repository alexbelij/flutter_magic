import 'dart:convert';

import 'package:app/app_data.dart';
import 'package:app/ui/search_page.dart';
import 'package:flutter/material.dart';
import 'package:app/models/end_point.dart';
import 'package:app/models/model_card.dart';
import 'package:app/ui/about_api_page.dart';
import 'package:app/ui/card_details.dart';
import 'package:cached_network_image/cached_network_image.dart';


enum Mode { list, grid, source }
enum MenuItems {search, /*toggleGridList,*/ about, viewSource}

class CardListing extends StatefulWidget {
  double offset = 0.0;

  void Function(AppData p) _themeUpdater;

  CardListing(void Function(AppData p) this._themeUpdater);

  double getOffsetMethod() {
    return offset;
  }
  void setOffsetMethod(double val) {
    offset=val;
  }

  @override
  _CardListingState createState() => new _CardListingState(Mode.grid);
}

class _CardListingState extends State<CardListing> {

  GlobalKey<ScaffoldState> _scaffoldKey;

  EndPoint ep;
  Mode mode;
  bool modeChangedAtRunTime = false;

  ScrollController _scrollController;

  List<ModelCard> selectedCards=new List<ModelCard>();

  _CardListingState(this.mode);

  EndPoint getEndPoint(){
    return appData.getCurrEndPoint();
  }
  List<ModelCard> epCards(){
    if (getEndPoint().cards!=null && getEndPoint().cards.length>0){
      return getEndPoint().cards;
    } else {
      //
      var cardsToRecycle=null;
      //If same url has already being downloaded in another, related, endpoint --> lets recycle them
      appData.endPoints().forEach((String key, EndPoint value){
        if (value.endpointUrl==ep.endpointUrl){
          if (value.cards!=null && value.cards.length>0){
            print ('recycled!');
            cardsToRecycle=value.cards;
          }
        }
      });
      if (cardsToRecycle!=null)
        return cardsToRecycle;
      else
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = new ScrollController(
        initialScrollOffset: widget.getOffsetMethod(),
        keepScrollOffset: true,
    );
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    this._scaffoldKey = new GlobalKey<ScaffoldState>();
    ep = getEndPoint();

    var sc=new Scaffold(
      resizeToAvoidBottomPadding:false,
      key: this._scaffoldKey,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );

    return new WillPopScope(
      onWillPop: () => _exitApp(context),
      child:sc
    );
  }
  Future<bool> _exitApp(BuildContext context) {
    return showDialog(
      context: context,
      child: new AlertDialog(
        title: new Text('Do you want to exit the app?'),
        actions: <Widget>[
          new FlatButton(
            textTheme: ep.epTheme.theme.buttonTheme.textTheme,
            onPressed: () => Navigator.of(context).pop(false),
            child: new Text('No'),
          ),
          new FlatButton(
            textTheme: ep.epTheme.theme.buttonTheme.textTheme,
            onPressed: () => Navigator.of(context).pop(true),
            child: new Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
  }

  _buildAppBar(BuildContext context) {
    return new AppBar(
        title: new Text(ep.endpointTitle),

        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.cloud), onPressed:_navigateConfig,),
          new PopupMenuButton(
            onSelected: (String value) { _handleMenuTap(context, value); },

            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[

              new PopupMenuItem<String>(value: "search", child: const Text('Search in results'),),
//              new PopupMenuItem<MenuItems>(value: MenuItems.toggleGridList, child: const Text('Toggle list/grid mode'),),
//              new PopupMenuDivider(),
//              new PopupMenuItem<MenuItems>(value: MenuItems.viewSource, child: const Text('View source'),),

              new PopupMenuDivider(),
              new PopupMenuItem<String>(value: "about", child: const Text('About this API'),),

            ],
          ),
    ]);
  }
  _handleSearch(){
    if (epCards().length>0){
      Navigator.push(context, new MaterialPageRoute(
          builder: (BuildContext context){return new SearchPage();}
      ));
    }
  }
  _navigateConfig(){
    Navigator.pushNamed(context, '/config');
  }
  _handleMenuTap(BuildContext context, String value) {
      switch (value) {
//        case MenuItems.toggleGridList:
//          appData.logEvent('listing_toggleGridList', {'ep':ep.endpointTitle});
//          setState(() {
//            if (this.mode == Mode.list)
//              this.mode = Mode.grid;
//            else
//              this.mode = Mode.list;
//
//            modeChangedAtRunTime = true;
//          });
//          break;

        case "about":
          new AboutAPIPage(this.ep.about).customDialogShow(context);
          break;

        case "search":
          _handleSearch();
          break;

        case "viewSource":
          setState(() {
            if (this.mode == Mode.source){
              if (ep.typeOfListing==TypeOfListing.list)
                this.mode=Mode.list;
              else
                this.mode=Mode.grid;
            }
            else
              this.mode = Mode.source;
            modeChangedAtRunTime = true;
          });
          break;
      }
  }

  _buildBody(BuildContext context) {
    appData.logEvent('listing_show', {'ep':ep.endpointTitle, 'typeOfListing':ep.typeOfListing.toString()} );

    var _cards=epCards();

    var setThemeIn10ms=(){
      if (this.ep.epTheme!=null && appData.themeApplied==this.ep.epTheme)
        return;

      print ('Screen repaint in 10ms');
      new Future.delayed(const Duration(milliseconds: 10), (){
        if (widget._themeUpdater!=null)
          widget._themeUpdater(appData); //forzamos tema
      });
    };

    if (_cards.length > 0) {
      setThemeIn10ms();

      return _buildGridOrList(context);
    } else {
      var ep=getEndPoint();

      return FutureBuilder<List<ModelCard>>(
          future: ep.fetchData(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              setThemeIn10ms();
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return _emptyState(snapshot.error);
            }

            // By default, show a loading spinner
            return Center(child: CircularProgressIndicator());
          });
    }
  }

  _buildGridOrList(BuildContext context) {
    if (this.mode == Mode.list)
      return _buildList(context, _buildRow);
    else if (this.mode==Mode.source)
      return _buildList(context, _buildSourceRow);
    else{
      if (this.ep.typeOfListing==TypeOfListing.match)
        return _buildList(context, _buildRow);
      else if (this.ep.typeOfListing==TypeOfListing.list)
        return _buildList(context, _buildRow);
      else
        return _buildGrid(context);
    }
  }

  _buildList(BuildContext context, Function(ModelCard card, int index, BuildContext context) fnBuildRow) {
    var _cards=epCards();

    _scrollController = new ScrollController(
      initialScrollOffset: widget.getOffsetMethod(),
      keepScrollOffset: true,
    );

    var lvw=ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: (_cards.length * 2) - 1,
        controller: _scrollController,
        itemBuilder: (context, index) {
          if (index.isOdd)
            return Divider(height:2.0);
          else {
            var nextIndex=index ~/ 2;
            print ('building listitem $nextIndex');
            return fnBuildRow(_cards[nextIndex], nextIndex, context);
          }
        }
    );

    return new NotificationListener(
      child:lvw,
      onNotification: (notification) {
        if (notification is ScrollNotification) {
          widget.setOffsetMethod(notification.metrics.pixels);
        }
      },
    );
  }
  _imgPlaceholder(){
    return new Center(child:Container(height:30.0, width:30.0, child:CircularProgressIndicator()));
  }
  Widget _imgErrorPlaceholder({double width, double height}){
    return new Container(color:Colors.black26, width: width??80.0, height:height??80.0,);
  }
  _buildRow(ModelCard card, int index, BuildContext context) {
    var tt=Theme.of(context).textTheme;
    var title=tt.title;
    var body=tt.body1;

    var primaryColor=Theme.of(context).primaryColor;

    if (this.ep.typeOfListing == TypeOfListing.match) { //TypeOfListing.match
      var f1 = card.get(this.ep.firstImageForListing().field);
      var s1 = (f1 != null ? f1 : ModelCard.getImgPlaceholder());

      var f2 = card.get(this.ep.secondImageForListing().field);
      var s2 = (f2 != null ? f2 : ModelCard.getImgPlaceholder());

      var txt1 = card.get(this.ep.firstName());
      if (txt1 == null) {txt1 = "Not found: ${this.ep.firstName()}";}

      var txt2 = card.get(this.ep.secondName());
      if (txt2 == null) {txt2 = "Not found: ${this.ep.firstName()}";}

      var team1=new Expanded(child:new Row(children: <Widget>[
        Text(txt1, style: body),
        Material(borderRadius: BorderRadius.circular(4.0), elevation: 5.0, child:
        CachedNetworkImage(imageUrl:this.ep.proxiedImage(s1), placeholder:_imgPlaceholder(), errorWidget:_imgErrorPlaceholder(width:40.0, height:30.0), height: 30.0, width: 40.0, fit: BoxFit.cover)
        )
      ], mainAxisAlignment: MainAxisAlignment.spaceBetween,)) ;
      var team2=new Expanded(child:new Row(children: <Widget>[
        Material(borderRadius: BorderRadius.circular(4.0), elevation: 5.0, child:
        CachedNetworkImage(imageUrl:this.ep.proxiedImage(s2), placeholder: _imgPlaceholder(), errorWidget:_imgErrorPlaceholder(width:40.0, height:30.0), height: 30.0, width: 40.0, fit: BoxFit.cover)
        ),
        Text(txt2, style: body)
      ], mainAxisAlignment: MainAxisAlignment.spaceBetween,));

      Widget sectionLabel;
      if (this.ep.section!=null){
        var ff=this.ep.section.field;
        var newSection=card.get(ff);
        var lastSection=index==0?null: epCards()[index-1].get(ff);

        if (newSection!=lastSection){
          sectionLabel=new Text(newSection, style:tt.caption, textAlign: TextAlign.start,);
        }
      }

      var gd=GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: new Container(
            child: Row(children: <Widget>[team1, SizedBox(width: 16.0, height: 60.0,), team2], mainAxisAlignment: MainAxisAlignment.spaceBetween,),
          ), onTap: () {
            print('tap');
            _navigateDetailPage(card, context);
          }
      );

      if (sectionLabel!=null){
        return new Column(children: <Widget>[
          new Container(height:32.0, child:sectionLabel, margin:EdgeInsets.only(top:20.0)),
          gd
        ], crossAxisAlignment: CrossAxisAlignment.start,);
      } else {
        return gd;
      }
    }
    else if (this.ep.typeOfListing == TypeOfListing.list) {
      var txt = card.get(this.ep.firstName());
      if (txt == null) {txt = "Not found: ${this.ep.firstName()}";}

      return ListTile(
        contentPadding: EdgeInsets.only(left:0.0, right:0.0),
        title: Text(txt, style: title,),
        trailing: Icon(Icons.panorama_fish_eye, color: primaryColor,),
        onTap: () {_navigateDetailPage(card, context);},
      );
    }
  }
  _buildSourceRow(ModelCard card, int index, BuildContext context) {
    var txt=card.get(this.ep.firstName());
    if (txt==null){
      txt="Not found: ${this.ep.firstName()}";
    }

    JsonEncoder encoder = new JsonEncoder.withIndent('  ');

    var j=json.encode(card.json);
    var pprint=( encoder.convert( json.decode(j) ) );

    return ListTile(
      contentPadding: EdgeInsets.only(left:0.0, right:0.0),
      title: Text(txt, style: Theme.of(context).textTheme.title,),
      subtitle: Text(pprint),
      trailing: Icon(Icons.code, color: Theme.of(context).primaryColor,),
      onTap:() {
        _navigateDetailPage(card, context);
      },
    );
  }

  _buildGrid(BuildContext context) {
    var _cards=epCards();

    double verticalMargin=0.0, horizontalMargin=0.0;
    if (this.ep.typeOfListing==TypeOfListing.gridWithoutName){
      verticalMargin=10.0;
      horizontalMargin=3.0;
    }

    _scrollController = new ScrollController(
      initialScrollOffset: widget.getOffsetMethod(),
      keepScrollOffset: true,
    );

    return new OrientationBuilder(
        builder: (context, orientation) {
          return new NotificationListener(child:new GridView.count(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
              mainAxisSpacing: verticalMargin,
              childAspectRatio: 1.1,
              crossAxisCount: (orientation == Orientation.portrait ? 2 : 3),
              children: List.generate(_cards.length, (index) {
                return _buildGridItem(_cards[index], index, context);
              })
          ),
          onNotification: (notification) {
            if (notification is ScrollNotification) {
              widget.setOffsetMethod(notification.metrics.pixels);
            }
          }
          );
        }
    );
  }
  _buildGridItem(ModelCard card, int index, BuildContext context) {
    var fi=card.get( this.ep.firstImageForListing().field );

    var src=this.ep.proxiedImage( (fi!=null?fi:ModelCard.getImgPlaceholder()) );

    var textStyle=Theme.of(context).textTheme.body1.copyWith(color: Colors.white);

    var txt=card.get(this.ep.firstName());
    if (txt==null){
      txt="Not found: ${this.ep.firstName()}";
    }

    Widget domcard, domImg, domTxt;

    var isSelected=this.selectedCards.contains(card);

    if (this.ep.typeOfListing==TypeOfListing.gridWithName) {
      domImg = CachedNetworkImage(imageUrl:this.ep.proxiedImage(src), fit: BoxFit.cover);

      domTxt = Container(
          height: 30.0,
          padding: EdgeInsets.only(top: 5.0),
          decoration: new BoxDecoration(color: Colors.black54),
          child: new Text(txt, style: textStyle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,),
      );

      domcard=new Container(
        color:isSelected?Theme.of(context).selectedRowColor:null,
        child:new GridTile(
          child: domImg,
          footer:domTxt
        )
      );

    } else if (this.ep.typeOfListing==TypeOfListing.gridWithoutName) {

      domImg = CachedNetworkImage(imageUrl:this.ep.proxiedImage(src), placeholder: _imgPlaceholder(), errorWidget:_imgErrorPlaceholder(), fit: BoxFit.fitHeight, );

      domcard=new Container(
        color:isSelected?Theme.of(context).accentColor:null,
        child:new GridTile(child: domImg,),
      );
    }

    return new GestureDetector(
      child:domcard,
      onTap: () {
        if (this.ep.typeOfDetail==TypeOfDetail.productCompare)
          _toggleSelection(card, context);
        else
          _navigateDetailPage(card, context);
      },
    );

  }
  _toggleSelection(ModelCard card, BuildContext context){
    var newSelectedCards=this.selectedCards.sublist(0);

    if (newSelectedCards.contains(card)){
      newSelectedCards.remove(card);
    } else{
      newSelectedCards.add(card);
    }

    if (newSelectedCards.length>=2){
      this.selectedCards.clear();
      _navigateDetailPage(newSelectedCards[0], context, cardToCompare: card,);
    } else {
      setState(() {this.selectedCards=newSelectedCards;});
    }
  }
  _navigateDetailPage(ModelCard card, BuildContext context, {ModelCard cardToCompare}) async {
//    Navigator.pushNamed(context, '/detail');//no se puede usar pushNamed porque no recibe ningún otro parámetro

    Navigator.push(context, new MaterialPageRoute(
      builder: (BuildContext context){
        if (ep.typeOfDetail==TypeOfDetail.productCompare){

          return new DetailPage.compare(card, cardToCompare);

        } else {
          return new DetailPage(card);

        }
      }
    ));
  }

  _emptyState(err){
    var tt=Theme.of(context).textTheme;

    var title='Unable to connect';
    var subtitle="Maybe it's not you but we can't find the resource. Tap to try again.";

    appData.logEvent('listing_error', {'ep':appData.getCurrEndPoint().endpointTitle, 'err':err.toString()});

//    if (err.toString().contains('SocketException')){
    return new GestureDetector(
        onTap: (){
          setState((){/*retry connection*/});
        },
        child:new Column(
          children: <Widget>[
              SizedBox(height: 100.0),
              new Icon(Icons.cloud_off, color:Colors.black45, size: 90.0),

              Text(title, style:tt.title),
              SizedBox(height: 10.0),

              new Container(padding:EdgeInsets.symmetric(horizontal: 16.0),
                  child:Text(subtitle, style:tt.subhead, textAlign: TextAlign.center,)
              )
          ],)
      );
//    }
  }
  void _showSnackbar(String text) {
    final snackBar =
        SnackBar(content: Text(text), duration: Duration(seconds: 3));
    if (this._scaffoldKey != null && this._scaffoldKey.currentState != null)
      this._scaffoldKey.currentState.showSnackBar(snackBar);
  }
}

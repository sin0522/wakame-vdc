DcmgrGUI.prototype.volumePanel = function(){
  var list_request = { "url":DcmgrGUI.Util.getPagePath('/volumes/show/',1) };
  
  DcmgrGUI.List.prototype.getEmptyData = function(){
    return [{
      "id":'',
      "wmi_id":'',
      "source":'',
      "owner":'',
      "visibility":'',
      "state":''
    }]
  }
  
  DcmgrGUI.Detail.prototype.getEmptyData = function(){
        return {
          "volume_id" : "-",
          "capacity" : "-",
          "snapshot" : "-",
          "created" : "-",
          "zone" : "-",
          "status" : "",
          "attachment_information" : "-"
        }
      }

  var c_list = new DcmgrGUI.List({
    element_id:'#display_volumes',
    template_id:'#volumesListTemplate'
  });
  
  c_list.setDetailTemplate({
    template_id:'#volumesDetailTemplate',
    detail_path:'/volumes/detail/'
  });
  
  c_list.element.bind('dcmgrGUI.contentChange',function(event,params){
    c_list.setData(params.data);
    c_list.multiCheckList(c_list.detail_template);
  });

  var c_pagenate = new DcmgrGUI.Pagenate({
    row:10,
    total:30 //todo:get total from dcmgr
  });
  
  var bt_refresh  = new DcmgrGUI.Refresh();
  
  var bt_create_volume = new DcmgrGUI.Dialog({
    target:'.create_volume',
    width:400,
    height:200,
    title:'Create Volume',
    path:'/create_volume',
    button:{
     "Create": function() { 
       var volume_size = $('#volume_size').val();
       var unit = $('#unit').find('option:selected').val();
       if(!volume_size){
         $('#volume_size').focus();
         return false;
       }
       var data = "size="+volume_size+"&unit="+unit;
       
       $.ajax({
          "type": "POST",
          "async": true,
          "url": '/volumes/create',
          "dataType": "json",
          "data": data,
          success: function(json,status){
            console.log(json);
          }
        });
       $(this).dialog("close");
      }
    }
  });

  var bt_delete_volume = new DcmgrGUI.Dialog({
    target:'.delete_volume',
    width:400,
    height:200,
    title:'Delete Volume',
    path:'/delete_volume',
    button:{
     "Close": function() { $(this).dialog("close"); },
     "Yes, Delete": function() { 
       var delete_volumes = $('#delete_volumes').find('li');
       var ids = []
       $.each(delete_volumes,function(){
         ids.push($(this).text())
       })
       
       var data = $.param({ids:ids})
       $.ajax({
          "type": "DELETE",
          "async": true,
          "url": '/volumes/delete',
          "dataType": "json",
          "data": data,
          success: function(json,status){
            console.log(json);
          }
        });
       c_list.changeStatus('deleting');
       $(this).dialog("close");
      }
    }
  });
  
  bt_create_volume.target.bind('click',function(){
    bt_create_volume.open();
  });
  
  bt_delete_volume.target.bind('click',function(){
    bt_delete_volume.open(c_list.getCheckedInstanceIds());
  });

  bt_refresh.element.bind('dcmgrGUI.refresh',function(){
    list_request.url = DcmgrGUI.Util.getPagePath('/volumes/show/',c_pagenate.current_page);
    c_list.element.trigger('dcmgrGUI.updateList',{request:list_request})
    
    //update detail
    $.each(c_list.checked_list,function(check_id,obj){
      $($('#detail').find('#'+check_id)).remove();
      c_list.checked_list[check_id].c_detail.update({
        url:DcmgrGUI.Util.getPagePath('/volumes/detail/',check_id)
      },true);
    });
  });
  
  c_pagenate.element.bind('dcmgrGUI.updatePagenate',function(){
    c_list.clearCheckedList();
    $('#detail').html('');
    bt_refresh.element.trigger('dcmgrGUI.refresh');
  });

  //list
  c_list.setData(null);
  c_list.update(list_request,true);
  
}
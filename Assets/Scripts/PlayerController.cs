using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour
{
    //TODO: CHange to private
    public Transform _playerTransform;
    public Transform startPosition; 

    private void Awake()
    {
        if (_playerTransform == null)
        {
            _playerTransform=GameObject.Find("Player").
                GetComponent<Transform>();
        }
    }
    private void Start()
    {
        if(_playerTransform!=null && startPosition!=null)
        {

            _playerTransform.position=startPosition.position;
            _playerTransform.rotation=startPosition-rotation;
        }    
    }

}
